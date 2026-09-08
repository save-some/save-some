# Product ingestion plan — RapidAPI now, scraper as a first-class track

Decision up front: **build both, behind one contract.** The RapidAPI adapters get real price history flowing this week (key, billing, JSON shape already proven with walmart-data); the scraper engine gets built as a permanent tier, not a consolation prize — per-retailer "recipes" that emit the exact same normalized objects, so a chain can flip from rapidapi → scraper → rapidapi without the writer, API, or app noticing anything. The durable asset is the contract + writer + schema; transports are disposable.

## Status (this file is kept updated as phases land)
- **Phase 1 — DONE.** `ingest/` package: `contract.py` (with boundary validation), `writer.py` (upc→difflib matching tiers, per-item SAVEPOINTs, `ingest_runs` bookkeeping, dry-run rollback), `budget.py` (monthly ledger), `run.py` CLI. `schema/ingest_additions.sql` applied live. Offline suite: `tests/test_contract.py`, `tests/test_smoke.py`.
- **Phase 2 — Walmart adapter DONE** (`sources/walmart_rapidapi.py`, pinned offline by `tests/test_walmart_adapter.py`). The live run against the real API (`python -m ingest.run --source walmart_rapidapi --queries "..." --dry-run`) spends RapidAPI quota, so it's a deliberate human invocation. Adapters for further chains need Phase 0 first.
- **Phase 0 — OPEN.** Needs the RapidAPI account: hub check per chain + the partner-API applications + the scrapeability probes below.
- Phases 3-5 — open; `seed/seed.py` remains until the adapters fully replace it.

## Phase 0 — Source catalog (~half a day, needs your RapidAPI account)
Per chain (Target, Home Depot, Lowe's, BJ's) check three doors, record all three:
1. **RapidAPI hub product** with search + product/price endpoints (host, plan, free-tier req/mo). Hit 3 real calls with your key; a chain qualifies only if price + name + id survive two consecutive calls.
2. **Official partner API** (Walmart Data Hub, Target Partners, Home Depot API): real, stable, ToS-clean — but gated behind business approval. Apply anyway (free, takes weeks); if one lands, it replaces everything else for that chain.
3. **Scrapeability probe**: from this VM's network, load 3 product pages + 1 search page with plain `curl`, then with headless Playwright. Score: does the HTML contain JSON-LD `Product` with `offers.price`? Does the search page render server-side or need JS? Do you meet a captcha/Akamai/PerimeterX wall? (Expect: product pages mostly render JSON-LD server-side; search pages heavily protected.)
Output: one table, one row per chain: `rapidapi | official | json-ld | search-html | captcha | decision`.

## Phase 1 — Ingest core (the thing both transports plug into)
New package, psycopg2 direct, reusing `api/utils.py` env conventions:
```
backend/ingest/
  contract.py    # NormalizedProduct dataclass (below) — the ONLY shape the writer sees
  writer.py      # idempotent upserts + ingest_runs bookkeeping
  budget.py      # per-source request ledger (quota)
  run.py         # CLI: python -m ingest.run --source walmart_rapidapi --queries "tv,drill"
  sources/
    walmart_rapidapi.py
    <chain>_rapidapi.py
    <chain>_scrape.py        # Phase 3, same entrypoint signature
```
Contract (fields = DB columns, nothing transport-specific):
`canonical: {upc?, name, brand, description?}` + `offer: {retailer, external_id, product_url, image_url?, price, original_price?, in_stock, source}`.

Writer semantics (all additive/idempotent, matching repo rules):
- `products`: match by `upc` first; else normalized `brand+name` via difflib ≥ 0.93 (NOT pg_trgm — not installed live); unmatched → insert canonical.
- `retailer_products`: `ON CONFLICT (retailer_id, external_id) DO UPDATE` (+ new `source` column so each row records which transport produced it).
- `product_prices`: always append — history is the point.
- Migration `schema/ingest_additions.sql` (additive, IF-NOT-EXISTS style): `CREATE TABLE ingest_runs(id, source, started, finished, fetched, created, matched, failed, error_sample)` + `CREATE UNIQUE INDEX ON products(upc) WHERE upc IS NOT NULL`.
- **Fail loudly**: per-item errors counted; any failure ⇒ nonzero exit + first traceback printed. "exit 0, wrote nothing" becomes structurally impossible — `ingest_runs` is the proof-of-life every run must leave.

## Phase 2 — Revive Walmart on RapidAPI + one qualifying chain (~1 day)
Port `seed/seed.py`'s parsing into `sources/walmart_rapidapi.py`; record 3 canned JSON responses as fixtures under `backend/tests/fixtures/`; unit-test normalize→contract, `'$49.88'` price parse, item-id-from-url. Then repeat for the first Phase-0-qualifying chain. Query list is demand-driven, not hopeful: distinct `search_history.query` + watchlist names + one probe per category — this is what makes free tiers last.

## Phase 3 — The scraper engine (first-class; ~3-5 days to first two chains, then maintenance)
Playwright (Python, headless Chromium). Structure per chain = a **recipe**, nothing else:
```python
# sources/bjs_scrape.py exposes RECIPE = {name, start_urls, search(q)->url,
#   product_fields: jsonld_selectors..., page_ready_selector, paginate, block_markers}
```
Plus one engine shared by all recipes:
- context warmup (visit homepage, accept nothing, settle cookies) before deep links;
- **JSON-LD first**: parse `application/ld+json` `Product`/`ItemList` blocks — server-rendered, survives most redesigns, gives name/sku/upc/price/availability. CSS-selector fallback dict per chain for when JSON-LD is missing;
- **block detection**: captcha selectors, 403 status, empty-product-marker page → raise `Blocked` → circuit-break that chain (writes `ingest_runs.failed`, flips nothing else), save HTML + screenshot to `ingest/evidence/` so recipes get fixed offline without hammering the site;
- pacing: per-chain polite delay + jitter, max N pages/run, retry once with fresh context;
- **proxy seam**: standard Playwright proxy env now; if a chain only ever answers through residential IPs, point that env var at a rotating-proxy vendor (Bright Data/Smartproxy/Oxylabs; ~$1-15/GB) — the engine's config line is the only thing that changes. Decision point, not surprise: if a chain's free-tier RapidAPI exists, buy/use it over paying proxy vendors.
- **fixture mode**: every scraped page saved; `sources/<chain>_scrape.py` parsers run against fixtures in pytest — recipes stay testable offline and redesigns show up as failing tests, not silent NULLs.
- Search pages are the heavily protected ones; product pages usually aren't. Strategy that exploits this: discovery via the cheap door (sitemap.xml URLs, RapidAPI search if any, watchlist external_ids already stored) → **prices via product pages** (the recurring refresh — exactly what the app needs most). Search scraping is then optional.

Chain order = Phase-0 scores, cheapest-block first (likely: BJ's / Lowe's → Home Depot → Target → Walmart-only-if-RapidAPI-dies). Each chain lives or dies alone: kill switch per recipe, one chain's wall never stalls the pipeline.

Legal/ethics lane (course-scale, keep it defensible): public pages only, no login, no PII, honor `robots.txt` where it covers the product pages you fetch, low volume (hundreds of pages/day, not tens of thousands), store only facts (prices/names/ids). Scraping ToS is grey; this posture keeps you on the factual-information, hiQ-flavored side of the line. Documented in `ingest/README.md`.

## Phase 4 — Scheduling & the refresh loop that keeps the app alive
- **Price-only refresh** (daily-ish cron on this VM): iterate existing `retailer_products` per chain, hit product page/endpoint, append one `product_prices` row. Cheap, bounded, and it's what makes sparklines/trending look alive — this is the loop that matters, not bulk acquisition.
- **Discovery sweep** (weekly): run the demand-driven query list through whichever search transport the chain has; new external_ids → details → first price row.
- Budget: `budget.py` refuses past ~80% of a chain's quota; scraper respects `max_requests_per_run` in `sources.yaml`.
- Later: GitHub Actions `schedule:` cron (needs the RapidAPI key as a secret) once ingestion must survive the VM.

## Phase 5 — Cross-retailer matching & audit
With multiple sources landing, matching is the product's core promise (price comparison IS the app): partial-unique upc index does the exact tier; a difflib pass proposes `canonical` merges (UPC-less items) into a review queue (`products_merge_candidates` table) instead of auto-merging; trending/offers queries unchanged.

## Acceptance
1. `python -m ingest.run --source walmart_rapidapi --queries "logitech g705"` → new/updated `retailer_products` + ≥1 fresh `product_prices` + an `ingest_runs` row; exit 0 only with `failed == 0`.
2. Run twice ⇒ no duplicate products/offers; exactly one new price row each.
3. Force a source error mid-list ⇒ nonzero exit, `ingest_runs.failed>0`, previously-written rows intact.
4. A scraper recipe against fixtures passes pytest with zero network.
5. Block simulation (point a recipe at a captcha page) ⇒ chain circuit-breaks, evidence saved, other chains unaffected.
6. `--dry-run` everywhere writes nothing.

## Cost/risk summary
- RapidAPI: $0 up to free tiers (~50–500 req/mo per hub product, inference), die-with-the-wrapper risk → mitigated by contract layer.
- Scraper: $0 infra on this VM; real cost is **maintenance per redesign/block** (expect 1 recipe fix/chain/quarter, more if a chain escalates); proxy cost only if a chain walls off datacenter/residential-IP traffic (decision point Phase 0 scores for you).
- Official partner APIs: $0, best long-term, slow gate — apply in Phase 0, thank yourself later.
- Biggest single risk: building scrapers before the ingest core exists (seed.py is the cautionary tale). Order above makes every transport a ~100-line drop-in, which is also why "I need the scraper eventually" stops being a big deal — it's just another recipe file.
