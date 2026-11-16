# IF4040 Project III – Basis Data Spasial (PostGIS)

Persebaran kota, sungai, dan karakteristik wilayah antarnegara di Asia.
Sumber data: Natural Earth 1:10m.

## Struktur

```
data/<tabel>/     hasil export data bersih (deliverable) + data/LOAD.md
data/raw/         shapefile mentah hasil download (tidak di-commit)
dumps/pdl.dump    dump database bersama
sql/              01_schema.sql (DDL + cleansing), 02..05 query per kategori
scripts/          download, import, dump, restore
screenshots/      peta hasil query dari QGIS
laporan/
```

## Setup database (sekali saja)

Yang perlu di-install: **Docker Desktop**, **Git** (Git Bash untuk menjalankan script), dan **QGIS**.

```bash
docker compose up -d            # PostgreSQL 17 + PostGIS 3.5, port 5433
```

Koneksi (psql / QGIS / DBeaver):

| host | port | database | user | password |
|---|---|---|---|---|
| localhost | 5433 | pdl | postgres | postgres |

Masuk psql: `docker compose exec db psql -U postgres -d pdl`

## Kalau hanya ingin memakai DB yang sudah jadi

```bash
git pull
bash scripts/db_restore.sh      # restore dari dumps/pdl.dump (DB pdl lokal ditimpa)
```

## Kalau mengisi tabel sendiri (alur load)

```bash
bash scripts/download_ne.sh ne_10m_populated_places ne_10m_airports   # -> data/raw/
bash scripts/import_raw.sh  ne_10m_populated_places ne_10m_airports   # -> raw.<layer>
docker compose exec db psql -U postgres -d pdl -c '\d raw.ne_10m_airports'  # cek nama kolom
# tulis INSERT ... SELECT dari raw ke tabel final, lalu:
bash scripts/db_dump.sh         # -> dumps/pdl.dump, commit & push
```

`01_schema.sql` meng-`DROP` lalu membuat ulang semua tabel final, jadi
jalankan hanya kalau memang ingin membangun ulang dari raw:

```bash
docker compose exec db psql -U postgres -d pdl -f /sql/01_schema.sql
```

Supaya tidak saling menimpa: satu orang (Orang 1) memegang dump "resmi".
Yang lain kirim script INSERT-nya ke `sql/`, lalu dump dibuat ulang.

## QGIS

Browser → PostgreSQL → New Connection → isi tabel koneksi di atas.
Hasil query: DB Manager → SQL Window → jalankan query → *Load as new layer* (kolom geometri `geom`).
