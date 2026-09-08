"""The single shape every transport speaks.

RapidAPI adapters, scrapers, and hand-written fixtures all emit these
objects; the writer only ever sees these. Nothing here is transport- or
database-specific — fields map 1:1 onto ``products`` / ``retailer_products``
/ ``product_prices`` columns so a chain can flip transports without the
writer noticing.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Protocol


@dataclass
class NormalizedProduct:
    """Canonical, retailer-agnostic product (maps to ``products``)."""
    name: str
    brand: str | None = None
    upc: str | None = None
    description: str | None = None
    image_url: str | None = None

    def __post_init__(self) -> None:
        # Cheap, loud, at the boundary: a transport that invents empty
        # names or non-http image links fails HERE, next to its own code,
        # instead of surfacing as a mystery row (or a DB error) inside the
        # writer three layers away.
        if not (self.name or "").strip():
            raise ValueError("NormalizedProduct.name must be non-empty")
        _require_url("NormalizedProduct.image_url", self.image_url)
        if self.upc is not None:
            self.upc = self.upc.strip() or None


@dataclass
class NormalizedOffer:
    """One retailer's listing of a product (maps to ``retailer_products``
    plus an appended ``product_prices`` row)."""
    retailer: str          # retailer NAME, resolved case-insensitively
    external_id: str       # Walmart item id, Target TCIN, etc.
    product_url: str | None
    price: float
    in_stock: bool = True
    source: str | None = None   # which transport produced this row
    image_url: str | None = None
    original_price: float | None = None

    def __post_init__(self) -> None:
        if not (self.retailer or "").strip():
            raise ValueError("NormalizedOffer.retailer must be non-empty")
        if not (self.external_id or "").strip():
            raise ValueError("NormalizedOffer.external_id must be non-empty")
        # A price observation of zero or less is exactly the silent
        # corruption the old seeder produced when parsing failed to 0.0 —
        # an offer without a real price is skipped by adapters, never
        # emitted.
        if not (self.price > 0):
            raise ValueError(
                f"NormalizedOffer.price must be > 0 (got {self.price!r})")
        if self.original_price is not None and not (self.original_price > 0):
            raise ValueError(
                "NormalizedOffer.original_price must be > 0 when present")
        _require_url("NormalizedOffer.product_url", self.product_url)
        _require_url("NormalizedOffer.image_url", self.image_url)


def _require_url(field: str, value: str | None) -> None:
    if value is not None and not value.startswith(("http://", "https://")):
        raise ValueError(f"{field} must be an absolute http(s) URL "
                         f"(got {value!r})")


@dataclass(frozen=True)
class Item:
    """A (product, offer) pair as returned by a source."""
    product: NormalizedProduct
    offer: NormalizedOffer


class Source(Protocol):
    """A transport: name + fetch(queries) -> iterable of (product, offer).

    Implementations may be lazy generators; the writer processes items one
    at a time so a mid-run failure keeps everything before it.
    """
    name: str

    def fetch(self, queries: Iterable[str]) -> Iterable[Item]:
        ...
