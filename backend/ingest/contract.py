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
