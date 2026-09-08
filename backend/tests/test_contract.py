"""The contract validates at its own boundary.

These are the mistakes a future transport author is most likely to make —
an empty name, a 0.0 price from a failed parse (the old seeder's signature
corruption), a relative "image" URL — and each must explode in the adapter,
not three layers away inside the writer or, worse, as a plausible-looking
row in the database.
"""
import pytest

from ingest.contract import Item, NormalizedOffer, NormalizedProduct


def offer(**overrides):
    base = dict(retailer="Walmart", external_id="3551794083",
                product_url="https://www.walmart.com/ip/x/3551794083",
                price=49.88, source="test")
    base.update(overrides)
    return NormalizedOffer(**base)


class TestNormalizedProduct:
    def test_minimal_valid(self):
        p = NormalizedProduct(name="65\" Samsung TV")
        assert p.brand is None and p.upc is None

    def test_empty_name_rejected(self):
        with pytest.raises(ValueError, match="name"):
            NormalizedProduct(name="   ")

    def test_upc_is_trimmed_and_blank_collapses_to_none(self):
        p = NormalizedProduct(name="x", upc="  887276512341  ")
        assert p.upc == "887276512341"
        assert NormalizedProduct(name="x", upc=" ").upc is None

    def test_relative_image_url_rejected(self):
        with pytest.raises(ValueError, match="image_url"):
            NormalizedProduct(name="x", image_url="/images/thumb.jpg")


class TestNormalizedOffer:
    def test_valid_minimal(self):
        o = offer()
        assert o.in_stock is True and o.original_price is None

    @pytest.mark.parametrize("price", [0, 0.0, -1, float("nan")])
    def test_non_positive_price_rejected(self, price):
        with pytest.raises(ValueError, match="price"):
            offer(price=price)

    def test_zero_price_error_names_the_value(self):
        # The message is the diagnosis: a failed "$" parse shows up here.
        with pytest.raises(ValueError, match="got 0\\.0"):
            offer(price=0.0)

    def test_blank_external_id_rejected(self):
        with pytest.raises(ValueError, match="external_id"):
            offer(external_id=" ")

    def test_blank_retailer_rejected(self):
        with pytest.raises(ValueError, match="retailer"):
            offer(retailer="")

    def test_non_http_product_url_rejected(self):
        with pytest.raises(ValueError, match="product_url"):
            offer(product_url="walmart.com/ip/x/1")

    def test_bad_original_price_rejected(self):
        with pytest.raises(ValueError, match="original_price"):
            offer(original_price=0)

    def test_item_wraps_pair(self):
        item = Item(NormalizedProduct(name="x"), offer())
        assert item.offer.price == 49.88
