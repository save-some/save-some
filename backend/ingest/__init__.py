"""Product ingestion core: contract, writer, budget, CLI.

Everything outside this package (the API, the Flutter app) only ever sees
rows these modules write. Transports (RapidAPI adapters, scrapers) are
drop-in modules under ``ingest.sources`` that emit the shapes in
``ingest.contract``; they never touch SQL.
"""
