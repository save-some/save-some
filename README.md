# Save Some 

## What is it ? 
This is an application designed to help people save money. The high level 
overview is that by aggregating price histories for various products as 
well as allowing users to compare the same products across inventories, 
I can help someone save money.

## How to run it? 

The frontend needs the REST API running, and the API needs a database. Commands
below are for a Unix environment; Windows hasn't been tested.

### 1. The database

Point the API at a Supabase project by filling in `backend/.env` (see
`backend/.env.example` for every variable).

If you'd rather not depend on Supabase — or you're somewhere its direct host is
unreachable, since it's IPv6-only — run a local Postgres instead. Apply the SQL
in this order:

```
createdb save_some
psql save_some -f backend/schema/local_dev.sql      # local only: auth.users stub + pg_trgm
psql save_some -f backend/schema/schema.sql
psql save_some -f backend/schema/api_additions.sql  # tables the REST API needs
psql save_some -f backend/seed/local_seed.sql       # local only: sample data
```

`local_dev.sql` supplies the two things Supabase provides implicitly: the `auth`
schema that `profiles.id` references, and the `pg_trgm` extension that
`helpers/db.py` needs for `similarity()`. Neither should be applied to Supabase.

`local_seed.sql` populates the retailers, products and prices shown in the Figma
design, so the UI can be compared against it directly.

### 2. The REST API

```
cd backend
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
./.venv/bin/python -m uvicorn api.main:application --reload --port 8000
```

Note the app object is named `application`, not `app`. Interactive docs are at
`http://127.0.0.1:8000/docs`.

Against a local database, override the connection without touching `.env`:

```
DATABASE_URL=postgresql://user:pass@127.0.0.1:5432/save_some \
  ./.venv/bin/python -m uvicorn api.main:application --port 8000
```

`DATABASE_URL` also covers Supabase's IPv4 connection pooler, whose username
(`postgres.<project-ref>`) doesn't fit the `DB_*` template.

### 3. The app

```
cd frontend/save-some-ui
cp .env.example .env      # required: pubspec declares .env as a bundled asset
flutter pub get
flutter run -d chrome
```

Every value in `.env` is optional. With `SUPABASE_URL` and `SUPABASE_ANON_KEY`
absent, the app skips authentication and signs in as the development user seeded
by `local_seed.sql`, so only `backend/.env` has to be filled in to see real data.
Add them to get the real sign-in flow. Override the API location with
`--dart-define=API_BASE_URL=...`.

MapBox has no web implementation, so on Chrome the map is replaced by a
placeholder of the same size; the surrounding store list works either way. For
the real map, run on Android:

```
flutter emulators --launch <your_emulator_id>
flutter run -d <device>
```

See [the Flutter Android setup guide](https://docs.flutter.dev/platform-integration/android/setup)
for creating an emulator.

### Checks

```
cd frontend/save-some-ui && flutter analyze && flutter test
```

## How does it work? 
This application aggregates product information from various sources, namely
websites for common retailers like BJ's, Walmart, Best Buy, Home Depot etc and
uses the aggregated data to give users access to price histories, comparisons
and tracking capabilities. 

Currently data is fetched from RapidAPI but a web scraper would be where the 
data originates from. Then product information is batch written to the database
where the REST API forwards JSON to the Flutter frontnend based on the page in 
the application being accessed. 

## Tech Stack
Backend 
- Python 
- Supabase

Frontend
- Flutter

Deployment 
- AWS (Amazon Web Services)
- Nginx (Web Proxy)



## Version Control
- `main` - stable, demo-ready code
- `dev` - integration branch for merging features
- `experimental/{name}` - risky spikes, uncertain features
- `feature/{name}` - short-lived, merged into dev
- `bugfix/{name}` - fixes, merged into dev
- `fix/{name}` - fixes, merged into dev
- `maintenance/name` - maintenance, corresponds with issues

## Directory Structure
```
.
├── backend
│   ├── api                 FastAPI app: routers, Pydantic models, DB handle
│   ├── helpers             SQL queries shared by the API
│   ├── requirements.txt
│   ├── schema              schema.sql, api_additions.sql, local_dev.sql
│   └── seed                RapidAPI scraper + local_seed.sql
├── frontend
│   └── save-some-ui
│       ├── assets          brand SVGs and the bundled display font
│       ├── lib
│       │   ├── config      environment and build-time configuration
│       │   ├── models      API response types
│       │   ├── screens     one file per tab, plus submit-a-product
│       │   ├── services    HTTP client and per-resource services
│       │   ├── theme       design tokens and ThemeData
│       │   └── widgets     shared components
│       └── test
└── README.md
```

## Design

The UI follows [this Figma file](https://www.figma.com/design/9ToSwbI0gQmLDJrlsjgvFr/save-some-ui).

Colours, spacing and radii live in `lib/theme/tokens.dart`, and `ThemeData` is
assembled in `lib/theme/app_theme.dart`. Screens should read from
`Theme.of(context)` rather than hardcoding values at the call site.

The palette is the Material 3 baseline on a warm cream canvas. The roles the
design specifies — accent `#6750A4`, card `#FEF7FF`, chip `#E8DEF8`, avatar
`#EADEFF` — are pinned explicitly over `ColorScheme.fromSeed`, because Flutter's
tonal algorithm drifts between versions and the design should win.
`test/theme_test.dart` asserts those exact values, so an upgrade that changes
them fails loudly rather than quietly shifting the design.
