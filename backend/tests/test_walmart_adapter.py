"""Offline tests for the Walmart adapter's parsing.

No network, no database: the adapter's whole job is turning the two raw
search shapes (plus URL/price quirks learned from the old seeder) into
contract objects or a deliberate skip. The HTTP layer itself is exercised
against the real API only via `python -m ingest.run --dry-run` by a human
with a key; everything below is pure.
"""
import pytest

from ingest.contract import Item
from ingest.sources import walmart_rapidapi as w
from ingest.sources.walmart_rapidapi import WalmartRapidApi


@pytest.fixture()
def src():
    return WalmartRapidApi()


class TestSearchShape:
    """/walmart-search.php: {title, link, image, price.rawPrice, outOfStock}"""

    RAW = {
        "title": "Samsung 65\" Class 4K UHD Smart LED TV",
        "link": ("https://www.walmart.com/api/tracker/rd="
                 "https%3A%2F%2Fwww.walmart.com%2Fip%2FSamsung-65"
                 "%2F3551794083&x=1"),
        "image": "https://i5.walmartimages.com/asst.jpg",
        "price": {"rawPrice": "497.99"},
        "outOfStock": False,
    }

    def test_full_item_maps_to_contract(self, src):
        item = src._parse(dict(self.RAW))
        assert isinstance(item, Item)
        product, offer = item.product, item.offer
        assert product.name.startswith("Samsung 65")
        assert product.image_url == self.RAW["image"]
        assert offer.retailer == "Walmart"
        assert offer.external_id == "3551794083"
        assert offer.product_url == (
            "https://www.walmart.com/ip/Samsung-65/3551794083")
        assert offer.price == 497.99
        assert offer.in_stock is True
        assert offer.source == "walmart_rapidapi"

    def test_out_of_stock_flag_maps(self, src):
        item = src._parse({**self.RAW, "outOfStock": True})
        assert item.offer.in_stock is False


class TestCategoryShape:
    """category listings: {name, url: '/p/...', images[], price '9.88',
    stock 'In stock'}"""

    RAW = {
        "name": "Duracell Coppertop AA 24-Pack",
        "url": "/p/duracell-coppertop/154797924",
        "images": ["https://i5.walmartimages.com/a.jpg"],
        "price": "$24.99",
        "stock": "In stock",
    }

    def test_relative_url_becomes_absolute_and_parsed(self, src):
        item = src._parse(dict(self.RAW))
        offer = item.offer
        assert offer.product_url == (
            "https://www.walmart.com/p/duracell-coppertop/154797924")
        assert offer.external_id == "154797924"
        assert offer.price == 24.99
        assert offer.image_url == self.RAW["images"][0]
        assert offer.in_stock is True

    def test_stock_string_out_of_stock(self, src):
        item = src._parse({**self.RAW, "stock": "Out of stock"})
        assert item.offer.in_stock is False


class TestSkips:
    """Each skip is a data shape the old seeder died noisily on."""

    def test_no_title(self, src):
        assert src._parse({"link": "https://www.walmart.com/ip/x/123"}) is None

    def test_unparseable_url_no_item_id(self, src):
        assert src._parse({"title": "X", "link": "https://example.com/a"}) is None

    def test_zero_price_skipped_not_emitted(self, src):
        # Contract validation rejects price<=0, so the adapter must SKIP
        # rather than construct — this test pins that division of labour.
        assert src._parse({
            "title": "X", "link": "https://www.walmart.com/ip/x/123",
            "price": "0.00"}) is None

    def test_junk_price_string(self, src):
        assert src._parse({
            "title": "X", "link": "https://www.walmart.com/ip/x/123",
            "price": "Contact store"}) is None


class TestHelpers:
    @pytest.mark.parametrize("value,want", [
        (49.88, 49.88), ("$49.88", 49.88), (49, 49.0),
        ({"rawPrice": "12.50"}, 12.50),
        ("junk", 0.0), (None, 0.0), ("1.2.3", 0.0),
    ])
    def test_price_parsing(self, value, want):
        assert WalmartRapidApi._price(value) == want

    @pytest.mark.parametrize("url,want", [
        ("https://www.walmart.com/ip/Foo/3551794083", "3551794083"),
        ("https://www.walmart.com/ip/3551794083", "3551794083"),
        ("https://www.walmart.com/p/foo/154797924", "154797924"),
        ("https://www.walmart.com/gp/product/987654321", "987654321"),
        ("/ip/Foo/99", "99"),
        ("https://example.com/a", None),
    ])
    def test_item_id_extraction(self, url, want):
        assert WalmartRapidApi._item_id(url) == want


class TestGuardrails:
    def test_fetch_without_key_is_a_clean_error(self, src, monkeypatch):
        monkeypatch.delenv("RAPIDAPI_KEY", raising=False)
        with pytest.raises(RuntimeError, match="RAPIDAPI_KEY"):
            list(src.fetch(["tv"]))

    def test_fetch_stops_at_monthly_budget(self, src, monkeypatch):
        monkeypatch.setenv("RAPIDAPI_KEY", "test-key")
        monkeypatch.setattr(w.budget, "over_budget",
                            lambda name, limit, **kw: True)
        with pytest.raises(RuntimeError, match="budget"):
            list(src.fetch(["tv"]))
