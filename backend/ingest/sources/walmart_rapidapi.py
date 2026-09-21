"""Walmart ingestion via the walmart-data RapidAPI hub product.

Ported from the request layer of the old ``seed/seed.py`` — the endpoints,
the tracking-URL unwrapping and the two search-response shapes — but
emitting ONLY contract objects and never touching a database: the writer
owns matching and writes. The part of seed.py that used to do the writing
called functions that did not exist, which is how it silently rotted; this
module cannot drift the same way because it has no SQL to rot in.

Response shapes (both seen in the wild, from seed.py's era):
  /walmart-search.php  -> {"products": [{title, link, image,
                          price: {"rawPrice": "49.88"}, outOfStock: bool}]}
  category listings    -> [{name, url: "/p/...", images: [...],
                          price: "9.88", stock: "In stock"}]
"""
from __future__ import annotations

import os
import random
import re
import time

import requests
from dotenv import load_dotenv

from .. import budget
from ..contract import Item, NormalizedOffer, NormalizedProduct

load_dotenv()

HOST = "walmart-data.p.rapidapi.com"
BASE = f"https://{HOST}"
SEARCH_PATH = "/walmart-search.php"

# Free-tier size for this hub product is whatever the plan says at signup
# time; overridable so a paid plan is a config change, not a code change.
MONTHLY_LIMIT = int(os.environ.get("INGEST_WALMART_LIMIT", "120"))

# Politeness floor between upstream calls, plus jitter — burst-free beats
# fast-and-blocked on a shared API gateway.
MIN_GAP_SECONDS = 0.4

_TIMEOUT_SECONDS = 30


class WalmartRapidApi:
    name = "walmart_rapidapi"

    def fetch(self, queries):
        key = os.environ.get("RAPIDAPI_KEY", "").strip()
        if not key:
            raise RuntimeError(
                "RAPIDAPI_KEY is not set — copy it into backend/.env "
                "(see backend/.env.example) to use walmart_rapidapi")
        headers = {"x-rapidapi-key": key, "x-rapidapi-host": HOST}

        for query in queries:
            payload = self._get(headers, {"query": query})
            for raw in payload.get("products", []):
                item = self._parse(raw)
                if item is not None:
                    yield item

    # -- transport ---------------------------------------------------------

    def _get(self, headers, params):
        # Checked per call, not just at start: a long run must stop at the
        # quota line instead of dying mid-month inside a 429.
        if budget.over_budget(self.name, MONTHLY_LIMIT):
            raise RuntimeError(
                f"monthly budget of {MONTHLY_LIMIT} requests exhausted for "
                f"{self.name}; raise INGEST_WALMART_LIMIT or wait for next "
                f"month")
        time.sleep(MIN_GAP_SECONDS + random.random() * 0.3)
        budget.record(self.name)
        response = requests.get(
            f"{BASE}{SEARCH_PATH}",
            headers=headers,
            params=params,
            timeout=_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        return response.json()

    # -- parsing (pure: pinned by offline fixture tests) --------------------

    def _parse(self, raw: dict) -> Item | None:
        """One search/category row -> one contract Item, or None to skip.

        Skip rules, each learned from the old seeder's data:
          * no title — nothing to file the product under;
          * no item id extractable from the URL — the offer's identity is
            the external id, and a guessed one poisons the unique key;
          * no positive price — an offer row without a price observation
            would be the only thing product_prices never wants.
        """
        title = (raw.get("title") or raw.get("name") or "").strip()
        if not title:
            return None

        raw_url = raw.get("link") or raw.get("url") or ""
        product_url = self._clean_url(raw_url)
        external_id = self._item_id(product_url)
        if external_id is None:
            return None

        images = raw.get("images")
        image_url = raw.get("image") or (
            images[0] if isinstance(images, list) and images else None)

        price = self._price(raw.get("price", 0))
        if price <= 0:
            return None

        stock_field = raw.get("stock")
        if stock_field is not None:
            out_of_stock = str(stock_field).lower() != "in stock"
        else:
            out_of_stock = bool(raw.get("outOfStock", False))

        return Item(
            NormalizedProduct(name=title, image_url=image_url),
            NormalizedOffer(
                retailer="Walmart",
                external_id=external_id,
                product_url=product_url or None,
                price=price,
                in_stock=not out_of_stock,
                image_url=image_url,
                source=self.name,
            ),
        )

    @staticmethod
    def _price(value) -> float:
        """'$49.88', 49.88, or {'rawPrice': '49.88'} -> 49.88; junk -> 0."""
        if isinstance(value, dict):
            value = value.get("rawPrice", 0)
        if isinstance(value, (int, float)):
            return float(value)
        if isinstance(value, str):
            cleaned = re.sub(r"[^\d.]", "", value)
            try:
                return float(cleaned) if cleaned else 0.0
            except ValueError:      # "1.2.3" — more than one dot
                return 0.0
        return 0.0

    @staticmethod
    def _clean_url(link: str) -> str:
        """Tracking redirects and relative paths -> canonical ip URL."""
        if link.startswith("/"):
            return f"https://www.walmart.com{link}"
        match = re.search(
            r"rd=(https%3A%2F%2Fwww\.walmart\.com%2Fip%2F[^&]+)", link)
        if match:
            from urllib.parse import unquote
            return unquote(match.group(1))
        return link

    @staticmethod
    def _item_id(url: str) -> str | None:
        """The trailing numeric segment of a walmart product URL.

        Three shapes reach this function: /ip/<slug>/<id> (search),
        /p/<slug>/<id> (category listings), and /gp/product/<id> —
        the id is always the final numeric segment.
        """
        match = re.search(r"/(?:ip|p|gp/product)/(?:[^/]+/)?(\d+)", url)
        return match.group(1) if match else None



SOURCE = WalmartRapidApi()
