# Instruksi Loading Data

Database: PostgreSQL 17 + PostGIS 3.5 (lihat `docker-compose.yml`), SRID 4326.

## 1. Data mentah → schema `raw`

Sumber: Natural Earth 1:10m (https://www.naturalearthdata.com/downloads/10m-cultural-vectors/
dan .../10m-physical-vectors/).

```bash
bash scripts/download_ne.sh
bash scripts/import_raw.sh ne_10m_admin_0_countries ne_10m_admin_1_states_provinces \
     ne_10m_populated_places ne_10m_airports ne_10m_rivers_lake_centerlines ne_10m_lakes
```

Opsi ogr2ogr yang dipakai: `-lco GEOMETRY_NAME=geom`, `-t_srs EPSG:4326`,
`-nlt PROMOTE_TO_MULTI` (kecuali layer titik).

## 2. raw → tabel final

```bash
docker compose exec db psql -U postgres -d pdl -f /sql/01_schema.sql
```

Skrip tersebut membangun keenam tabel final. `cities` dihubungkan ke negara Asia
melalui `adm0_a3`; `airports` dipilih berdasarkan lokasi di dalam negara; `rivers`
dan `lakes` dipilih jika geometri beririsan dengan negara Asia. Geometri sungai dan
danau diperbaiki sebelum disimpan.

## 3. Dump seluruh tabel final

Setelah hasil validasi pada akhir skrip menunjukkan keenam tabel dan `invalid = 0`:

```bash
bash scripts/db_dump.sh
```

Perintah ini memperbarui `dumps/pdl.dump` dengan schema dan data semua tabel di
schema `public` (countries, provinces, cities, airports, rivers, dan lakes).

## 4. Alternatif: restore dari dump

```bash
bash scripts/db_restore.sh dumps/pdl.dump
```
