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

## Skema

Semua geometri disimpan di SRID 4326 (WGS 84, satuan derajat). Untuk jarak, luas,
atau buffer dalam meter, cast ke `::geography`.

```
countries (country_code) ◄── FK ── provinces (country_code)
          (country_code) ◄── FK ── cities    (country_code)

countries ┄┄ spasial ┄┄ airports  (ST_Contains)
countries ┄┄ spasial ┄┄ rivers    (ST_Intersects)
countries ┄┄ spasial ┄┄ lakes     (ST_Intersects)
```

- **Kunci negara = `adm0_a3`, bukan `iso_a3`.** `iso_a3` bernilai `-99` untuk wilayah
  sengketa, sedangkan `adm0_a3` selalu terisi dan juga ada di data provinsi dan kota.
- **`airports`, `rivers`, `lakes` tidak punya FK.** Sumber bandara tidak punya kode negara,
  dan satu sungai/danau bisa melewati beberapa negara (many-to-many). Relasinya dihitung
  secara spasial saat query.
- **`cities` langsung ke `countries`, tidak lewat `provinces`.** Data kota tidak punya kunci
  provinsi yang cocok. Menyimpan `province_id` sekaligus `country_code` juga menjadi
  dependensi transitif (melanggar 3NF).
- **Polygon dan line disimpan sebagai Multi\*.** Banyak negara/provinsi berupa kepulauan.

Kolom *Sumber* = nama kolom di schema `raw` setelah import ogr2ogr (huruf kecil).

### countries (`ne_10m_admin_0_countries`)
| Atribut | Tipe | Constraint | Sumber | Keterangan |
|---|---|---|---|---|
| country_id | SERIAL | PK | – | ID unik negara |
| country_code | CHAR(3) | NOT NULL, UNIQUE | `adm0_a3` | Kode negara 3 huruf Natural Earth; dirujuk FK `provinces` dan `cities` |
| iso_a3 | VARCHAR(3) | NULL | `iso_a3` | Kode ISO 3166-1 alpha-3; `-99` diubah menjadi NULL |
| name | VARCHAR(100) | NOT NULL | `name` | Nama negara (bahasa Inggris) |
| continent | VARCHAR(50) | NOT NULL | `continent` | Benua; dipakai untuk filter Asia |
| subregion | VARCHAR(50) | NULL | `subregion` | Subwilayah PBB (South-Eastern Asia, dll.) |
| pop_est | BIGINT | CHECK ≥ 0 | `pop_est` | Estimasi jumlah penduduk |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometri | Batas wilayah negara |

### provinces (`ne_10m_admin_1_states_provinces`)
| Atribut | Tipe | Constraint | Sumber | Keterangan |
|---|---|---|---|---|
| province_id | SERIAL | PK | – | ID unik provinsi |
| name | VARCHAR(150) | NOT NULL | `name` | Nama provinsi/negara bagian |
| country_code | CHAR(3) | NOT NULL, FK → countries | `adm0_a3` | Negara tempat provinsi berada |
| admin_type | VARCHAR(50) | NULL | `type_en` | Jenis wilayah (Province, State, Prefecture, ...) |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometri | Batas wilayah provinsi |

### cities (`ne_10m_populated_places`)
| Atribut | Tipe | Constraint | Sumber | Keterangan |
|---|---|---|---|---|
| city_id | SERIAL | PK | – | ID unik kota |
| name | VARCHAR(150) | NOT NULL | `name` | Nama kota |
| country_code | CHAR(3) | FK → countries | `adm0_a3` | Negara tempat kota berada |
| population | BIGINT | CHECK ≥ 0 | `pop_max` | Estimasi jumlah penduduk |
| geom | geometry(Point, 4326) | NOT NULL, GiST | geometri | Lokasi kota |

### airports (`ne_10m_airports`)
| Atribut | Tipe | Constraint | Sumber | Keterangan |
|---|---|---|---|---|
| airport_id | SERIAL | PK | – | ID unik bandara |
| name | VARCHAR(150) | NOT NULL | `name` | Nama bandara |
| iata_code | VARCHAR(3) | NULL | `iata_code` | Kode IATA (misalnya CGK) |
| geom | geometry(Point, 4326) | NOT NULL, GiST | geometri | Lokasi bandara; negara dicari dengan `ST_Contains` |

### rivers (`ne_10m_rivers_lake_centerlines`)
| Atribut | Tipe | Constraint | Sumber | Keterangan |
|---|---|---|---|---|
| river_id | SERIAL | PK | – | ID unik segmen sungai |
| name | VARCHAR(150) | NULL | `name` | Nama sungai; ada segmen tanpa nama |
| scalerank | SMALLINT | NULL | `scalerank` | Tingkat kepentingan kartografis (kecil = penting) |
| geom | geometry(MultiLineString, 4326) | NOT NULL, GiST | geometri | Jalur sungai; negara dicari dengan `ST_Intersects` |

### lakes (`ne_10m_lakes`)
| Atribut | Tipe | Constraint | Sumber | Keterangan |
|---|---|---|---|---|
| lake_id | SERIAL | PK | – | ID unik danau |
| name | VARCHAR(150) | NULL | `name` | Nama danau; boleh kosong |
| scalerank | SMALLINT | NULL | `scalerank` | Tingkat kepentingan kartografis |
| geom | geometry(MultiPolygon, 4326) | NOT NULL, GiST | geometri | Area danau; negara dicari dengan `ST_Intersects` |

## Setup database (sekali saja)

Yang perlu di-install: **Docker Desktop**, **Git** (Git Bash untuk menjalankan script), dan **QGIS**.

```bash
git clone <url-repo> && cd project3-pdl
docker compose up -d            # PostgreSQL 17 + PostGIS 3.5, port 5433
bash scripts/db_restore.sh      # isi DB dari dumps/pdl.dump (DB pdl lokal ditimpa)
```

Koneksi:

| host | port | database | user | password |
|---|---|---|---|---|
| localhost | 5433 | pdl | postgres | postgres |

Port 5433 (bukan 5432) supaya tidak bentrok dengan PostgreSQL yang mungkin sudah terinstall di laptop.

## Mencoba akses database

Masuk psql di dalam container (tidak perlu install psql):

```bash
docker compose exec db psql -U postgres -d pdl
```

Lalu coba:

```sql
\dt                                   -- daftar tabel
\d countries                          -- struktur tabel
SELECT postgis_full_version();        -- cek PostGIS aktif
SELECT country_code, name, subregion FROM countries ORDER BY name LIMIT 10;
SELECT country_code, COUNT(*) FROM provinces GROUP BY 1 ORDER BY 2 DESC LIMIT 5;
-- contoh query spasial: luas Indonesia dalam km²
SELECT ST_Area(geom::geography) / 1e6 AS luas_km2 FROM countries WHERE country_code = 'IDN';
\q                                    -- keluar
```

Bisa juga pakai DBeaver/pgAdmin dengan data koneksi di atas.

## Membuka di QGIS

1. **Tambah koneksi.** Di panel *Browser*, klik kanan **PostgreSQL** → **New Connection...**
   - Name: `pdl`, Host: `localhost`, Port: `5433`, Database: `pdl`
   - Authentication → tab *Basic*: user `postgres`, password `postgres` (centang *Store*)
   - Klik **Test Connection** → **OK**.
2. **Tampilkan tabel.** Di *Browser* buka **PostgreSQL → pdl → public**, lalu
   double-click (atau drag ke peta) `countries`, `provinces`, dll.
3. **Tampilkan hasil query.** Menu **Database → DB Manager** → pilih *PostGIS → pdl* →
   klik ikon **SQL Window**. Tulis query (misalnya dari `sql/02_query_B.sql`) → **Execute**.
   Centang **Load as new layer**, isi *Geometry column* = `geom`. Kalau query hanya
   mengembalikan `geom`, biarkan *Column(s) with unique values* tidak dicentang
   (QGIS membuat ID baris sendiri). Beri nama layer, lalu klik **Load**.
4. Supaya peta konteks terlihat, tambahkan `countries` sebagai layer dasar di bawah layer
   hasil query, dan beri warna berbeda (klik kanan layer → *Properties → Symbology*).
5. Screenshot peta: **Project → Import/Export → Export Map to Image...**, simpan ke `screenshots/`.

Kalau koneksi gagal, pastikan container jalan: `docker compose ps` (status harus `healthy`).

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
MSYS_NO_PATHCONV=1 docker compose exec db psql -U postgres -d pdl -f /sql/01_schema.sql
```

Supaya tidak saling menimpa: satu orang (Orang 1) memegang dump "resmi".
Yang lain kirim script INSERT-nya ke `sql/`, lalu dump dibuat ulang.

## Dump & restore manual (tanpa script)

```bash
# dump
docker compose exec -T db pg_dump -U postgres -d pdl -Fc --no-owner -n public > dumps/pdl.dump

# restore
docker compose exec -T db dropdb   -U postgres --if-exists --force pdl
docker compose exec -T db createdb -U postgres -T template0 pdl
docker compose exec -T db psql     -U postgres -d pdl -c "CREATE EXTENSION postgis; CREATE SCHEMA raw;"
docker compose exec -T db pg_restore -U postgres -d pdl --no-owner -n public < dumps/pdl.dump
```
