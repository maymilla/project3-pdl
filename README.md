# IF4040 Project III: Spatial Database (PostGIS)

This repo models Asian geography in PostgreSQL with PostGIS: 59 countries, their provinces,
cities, airports, rivers, lakes, and the surrounding ocean. You query it with SQL and view the
results as maps in QGIS. All data comes from Natural Earth at 1:10m scale.

## Repository layout

```
data/<table>/       cleaned data per table (deliverable), plus data/LOAD.md
data/raw/           raw Natural Earth shapefiles (git ignores this folder)
dumps/pdl.dump      shared database dump
sql/01_schema.sql   DDL, loading, and cleansing for all seven tables
sql/QueryA..E/      queries per category (A descriptive, B spatial, C mixed, D interactive, E spatial aggregate)
scripts/            download, import, dump, restore
skema_project3.drawio   ERD
screenshots/        QGIS map exports
```

## Schema

Every geometry column uses SRID 4326 (WGS 84). Its unit is degrees, so cast to `::geography`
whenever you measure distance, area, or buffers in meters.

```
countries (country_code) ◄── FK ── provinces (country_code)
          (country_code) ◄── FK ── cities    (country_code)

countries ┄┄ spatial ┄┄ airports  (ST_Covers)
countries ┄┄ spatial ┄┄ rivers    (ST_Intersects)
countries ┄┄ spatial ┄┄ lakes     (ST_Intersects)
countries ┄┄ spatial ┄┄ oceans    (ST_Intersects)
```

Design decisions:

- **Country key is `adm0_a3`.** Natural Earth fills `iso_a3` with `-99` for disputed areas.
  `adm0_a3` always has a value and appears in the province and city data too.
- **Four tables have no foreign key.** The airport source carries no country code. A river,
  lake, or ocean can touch several countries, which makes the relation many-to-many. Queries
  compute these relations with spatial predicates.
- **`cities` points straight to `countries`.** The city data names its province only as free
  text, and storing both `province_id` and `country_code` would break 3NF. When you need a
  city's province, compute it with `ST_Within`.
- **Polygons and lines use Multi types.** Many Asian countries are archipelagos. A plain
  `Polygon` column rejects them.
- **Russia stays out.** Natural Earth labels it `continent = 'Europe'`, and the filter follows
  the source label.

Column *Source* lists the field name in the `raw` schema after the ogr2ogr import.

### countries (`ne_10m_admin_0_countries`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| country_id | SERIAL | PK | – | |
| country_code | CHAR(3) | NOT NULL, UNIQUE | `adm0_a3` | Referenced by `provinces` and `cities` |
| iso_a3 | VARCHAR(3) | NULL | `iso_a3` | `-99` becomes NULL |
| name | VARCHAR(100) | NOT NULL | `name` | English name |
| continent | VARCHAR(50) | NOT NULL | `continent` | Filter for Asia |
| subregion | VARCHAR(50) | NULL | `subregion` | UN subregion |
| pop_est | BIGINT | CHECK ≥ 0 | `pop_est` | Population estimate |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometry | Country boundary |

### provinces (`ne_10m_admin_1_states_provinces`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| province_id | SERIAL | PK | – | |
| name | VARCHAR(150) | NOT NULL | `name` | |
| country_code | CHAR(3) | NOT NULL, FK → countries | `adm0_a3` | |
| admin_type | VARCHAR(50) | NULL | `type_en` | Province, State, Prefecture, ... |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometry | Province boundary |

### cities (`ne_10m_populated_places`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| city_id | SERIAL | PK | – | |
| name | VARCHAR(150) | NOT NULL | `name` | |
| country_code | CHAR(3) | FK → countries | `adm0_a3` | |
| population | BIGINT | CHECK ≥ 0 | `pop_max` | Negative source values become NULL |
| geom | geometry(Point, 4326) | NOT NULL, GiST | geometry | |

### airports (`ne_10m_airports`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| airport_id | SERIAL | PK | – | |
| name | VARCHAR(150) | NOT NULL | `name` | |
| iata_code | VARCHAR(3) | NULL | `iata_code` | 8 airports have none |
| geom | geometry(Point, 4326) | NOT NULL, GiST | geometry | Country via `ST_Covers`, so coastline points count |

### rivers (`ne_10m_rivers_lake_centerlines`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| river_id | SERIAL | PK | – | One row per segment |
| name | VARCHAR(150) | NULL | `name` | 26 segments have no name |
| scalerank | SMALLINT | NULL | `scalerank` | Lower means more important |
| geom | geometry(MultiLineString, 4326) | NOT NULL, GiST | geometry | Stored whole, not clipped at Asia's edge |

### lakes (`ne_10m_lakes`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| lake_id | SERIAL | PK | – | |
| name | VARCHAR(150) | NULL | `name` | 87 lakes have no name |
| scalerank | SMALLINT | NULL | `scalerank` | |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometry | |

### oceans (`ne_10m_ocean`)
| Column | Type | Constraint | Source | Notes |
|---|---|---|---|---|
| ocean_id | SERIAL | PK | – | |
| scalerank | SMALLINT | NULL | `scalerank` | |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometry | World ocean clipped to 200 km around Asian land |

Row counts after cleansing: 59 countries, 1,102 provinces, 1,794 cities, 219 airports,
306 river segments, 238 lakes, 1 ocean polygon. No table holds an invalid geometry.

## Setup

Install **Docker Desktop**, **Git** (Git Bash runs the scripts on Windows), and **QGIS**.

```bash
git clone <repo-url> && cd project3-pdl
docker compose up -d            # PostgreSQL 17 + PostGIS 3.5 on port 5433
bash scripts/db_restore.sh      # loads dumps/pdl.dump and replaces your local pdl database
```

| host | port | database | user | password |
|---|---|---|---|---|
| localhost | 5433 | pdl | postgres | postgres |

The container listens on 5433 so it won't clash with a PostgreSQL install on 5432.

If Docker answers with `500 Internal Server Error`, restart Docker Desktop. If that fails, run
`wsl --shutdown` in PowerShell and open Docker Desktop again.

## Query the database

Open psql inside the container. You don't need psql on your machine.

```bash
docker compose exec db psql -U postgres -d pdl
```

```sql
\dt                                  -- list tables
\d countries                         -- table structure
\i /sql/QueryB/q1.sql                -- run a query file (sql/ is mounted at /sql)
SELECT ST_Area(geom::geography) / 1e6 AS area_km2 FROM countries WHERE country_code = 'IDN';
\q
```

Run a file without entering psql:

```bash
MSYS_NO_PATHCONV=1 docker compose exec db psql -U postgres -d pdl -f /sql/QueryB/q1.sql
```

Git Bash rewrites `/sql/...` into `C:/Program Files/Git/sql/...` unless you set
`MSYS_NO_PATHCONV=1`. PowerShell doesn't need it.

Category B queries return only `geom`, which psql prints as hex. To check a result in the
terminal, count the rows or select a name column for your own inspection:

```sql
SELECT count(*) FROM ( <query> ) q;
```

## View results in QGIS

1. **Connect.** In the Browser panel, right-click **PostgreSQL → New Connection**. Enter the
   connection values above, click **Test Connection**, then **OK**.
2. **Add base layers.** Open **PostgreSQL → pdl → public** and double-click `countries` or
   `provinces`. Give them a light grey fill.
3. **Run a query.** Open **Database → DB Manager**, select **PostgreSQL → pdl**, and press
   **F2** for the SQL Window. Paste the query and click **Execute**.
4. **Load it as a layer.** Tick **Load as new layer**, set the geometry column to `geom`, and
   leave the unique-values box unticked. Name the layer and click **Load**.
5. **Style it.** Drag the result above the base layer and give it a strong colour. For lines,
   set the width to 0.8 or more.
6. **Export.** Use **Project → Import/Export → Export Map to Image** and save to `screenshots/`.

After a restore, right-click **PostgreSQL → pdl → Refresh** so QGIS sees the new tables.

## Load data from scratch

You only need this to rebuild the database from the raw shapefiles.

```bash
bash scripts/download_ne.sh                       # all seven datasets into data/raw/
bash scripts/import_raw.sh ne_10m_admin_0_countries ne_10m_admin_1_states_provinces \
  ne_10m_populated_places ne_10m_airports ne_10m_rivers_lake_centerlines ne_10m_lakes ne_10m_ocean
MSYS_NO_PATHCONV=1 docker compose exec db psql -U postgres -d pdl -f /sql/01_schema.sql
bash scripts/db_dump.sh                           # writes dumps/pdl.dump
```

`01_schema.sql` drops and recreates every final table, then loads `countries` first because
the other six tables filter against it. One person owns the official dump. Send your INSERT
changes to `sql/` and that person regenerates `dumps/pdl.dump`.

The dump holds the `public` schema only. Queries must read the final tables, never `raw.*`,
or they fail on a restored database.

## Manual dump and restore

```bash
# dump
docker compose exec -T db pg_dump -U postgres -d pdl -Fc --no-owner -n public > dumps/pdl.dump

# restore
docker compose exec -T db dropdb   -U postgres --if-exists --force pdl
docker compose exec -T db createdb -U postgres -T template0 pdl
docker compose exec -T db psql     -U postgres -d pdl -c "CREATE EXTENSION postgis; CREATE SCHEMA raw;"
docker compose exec -T db pg_restore -U postgres -d pdl --no-owner -n public < dumps/pdl.dump
```

`-n public` on `pg_restore` skips the `CREATE SCHEMA public` statement, which would otherwise
fail on the existing schema.
