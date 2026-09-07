# ingest/sources

Transports are disposable; the contract is not. Each adapter is one module
here exposing a module-level `SOURCE` object:

```python
# sources/walmart_rapidapi.py
from ingest.contract import Item, NormalizedProduct, NormalizedOffer

class WalmartRapidApi:
    name = "walmart_rapidapi"          # also the budget ledger key

    def fetch(self, queries):          # -> Iterable[(product, offer)]
        for q in queries:
            resp = requests.get(...)   # budget.record(self.name) per call
            for raw in resp.json()["items"]:
                yield Item(
                    NormalizedProduct(
                        name=raw["name"], brand=raw.get("brand"),
                        upc=raw.get("upc"), description=raw.get("description"),
                    ),
                    NormalizedOffer(
                        retailer="Walmart", external_id=raw["id"],
                        product_url=f"https://walmart.com/ip/{raw['id']}",
                        price=float(raw["salePrice"]),
                        original_price=float(raw["msrp"]) if raw.get("msrp") else None,
                        in_stock=raw["stock"] == "instock",
                        source=self.name,
                    ),
                )

SOURCE = WalmartRapidApi()
```

Rules every adapter must follow:

1. Emit only contract objects — no dicts, no SQL, no retailer ids (the
   writer resolves names case-insensitively).
2. `fetch` should be a generator: the writer processes items one at a time
   inside per-item SAVEPOINTs, so a mid-run failure keeps earlier rows.
3. Charge `budget.record(self.name)` per upstream request and refuse to
   start when `budget.over_budget(self.name, limit)`.
4. Parse transport quirks into contract types here (e.g. `"$49.88"` ->
   `49.88`), never in the writer.
5. Name the file `<chain>_<transport>.py` (e.g. `bjs_scrape.py`), so
   flipping a chain from rapidapi to scraper is a cron-line change.

Nothing is checked in here yet by design: the first adapters arrive with
Phase 2 (RapidAPI ports of seed.py's parsing) and Phase 3 (scraper
recipes), each with fixtures under `backend/tests/fixtures/`.
