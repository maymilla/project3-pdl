-- =====================================================================
-- IF4040 Project III - Basis Data Spasial
-- 01_schema.sql  (Orang 1: model relasional + DDL)
-- Scope: Asia | SRID penyimpanan: EPSG:4326
-- CATATAN: nama kolom sumber (raw.*) diambil dari Natural Earth 1:10m
--          setelah di-import dengan ogr2ogr (huruf kecil). CEK ULANG
--          dengan \d raw.<tabel> sebelum menjalankan bagian 3.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS raw;   -- tempat data mentah hasil import

-- ---------------------------------------------------------------------
-- 1. DROP (supaya script bisa dijalankan ulang)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS airports, cities, rivers, lakes, provinces, countries CASCADE;

-- ---------------------------------------------------------------------
-- 2. DDL - tabel final (kontrak skema bersama)
-- ---------------------------------------------------------------------

-- Negara (region) - kunci penghubung deskriptif: country_code = ADM0_A3
CREATE TABLE countries (
    country_id    SERIAL PRIMARY KEY,
    country_code  CHAR(3)      NOT NULL UNIQUE,   -- ADM0_A3 (selalu terisi, beda dg ISO_A3 yg kadang -99)
    iso_a3        VARCHAR(3),                     -- boleh NULL jika sumber = '-99'
    name          VARCHAR(100) NOT NULL,
    continent     VARCHAR(50)  NOT NULL,
    subregion     VARCHAR(50),
    pop_est       BIGINT       CHECK (pop_est >= 0),
    geom          geometry(MultiPolygon, 4326) NOT NULL
);

-- Provinsi / admin-1 (region). Multi karena banyak provinsi berupa kepulauan.
CREATE TABLE provinces (
    province_id   SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    country_code  CHAR(3)      NOT NULL REFERENCES countries(country_code),
    admin_type    VARCHAR(50),                    -- Province, State, Prefecture, ...
    geom          geometry(MultiPolygon, 4326) NOT NULL
);

-- Kota (point) - Orang 2 yang mengisi data
CREATE TABLE cities (
    city_id       SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    country_code  CHAR(3)      REFERENCES countries(country_code),
    population    BIGINT       CHECK (population >= 0),
    geom          geometry(Point, 4326) NOT NULL
);

-- Bandara (point) - Orang 2. Sumber tidak punya kode negara -> relasi via spasial.
CREATE TABLE airports (
    airport_id    SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    iata_code     VARCHAR(3),
    geom          geometry(Point, 4326) NOT NULL
);

-- Sungai (polyline) - Orang 3. Satu sungai bisa melewati banyak negara -> tanpa FK.
CREATE TABLE rivers (
    river_id      SERIAL PRIMARY KEY,
    name          VARCHAR(150),
    scalerank     SMALLINT,
    geom          geometry(MultiLineString, 4326) NOT NULL
);

-- Danau (region) - Orang 4
CREATE TABLE lakes (
    lake_id       SERIAL PRIMARY KEY,
    name          VARCHAR(150),
    scalerank     SMALLINT,
    geom          geometry(MultiPolygon, 4326) NOT NULL
);

-- Indeks spasial (GiST) + indeks FK
CREATE INDEX idx_countries_geom ON countries USING GIST (geom);
CREATE INDEX idx_provinces_geom ON provinces USING GIST (geom);
CREATE INDEX idx_cities_geom    ON cities    USING GIST (geom);
CREATE INDEX idx_airports_geom  ON airports  USING GIST (geom);
CREATE INDEX idx_rivers_geom    ON rivers    USING GIST (geom);
CREATE INDEX idx_lakes_geom     ON lakes     USING GIST (geom);
CREATE INDEX idx_provinces_cc   ON provinces (country_code);
CREATE INDEX idx_cities_cc      ON cities    (country_code);

-- ---------------------------------------------------------------------
-- 3. LOAD + CLEANSING dari raw -> final (bagian Orang 1)
--    Jalankan setelah import shapefile ke schema raw (lihat data/LOAD.md)
-- ---------------------------------------------------------------------

-- 3a. Countries: filter Asia, -99 -> NULL, paksa MultiPolygon, perbaiki geometri invalid
INSERT INTO countries (country_code, iso_a3, name, continent, subregion, pop_est, geom)
SELECT adm0_a3,
       NULLIF(iso_a3, '-99'),
       name,
       continent,
       subregion,
       pop_est::BIGINT,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
FROM raw.ne_10m_admin_0_countries
WHERE continent = 'Asia';
-- KEPUTUSAN KELOMPOK: Rusia di Natural Earth berlabel continent = 'Europe'.
-- Jika ingin ikut, ganti WHERE di atas menjadi:
--   WHERE continent = 'Asia' OR adm0_a3 = 'RUS'

-- 3b. Provinces: hanya provinsi dari negara yang sudah masuk countries
INSERT INTO provinces (name, country_code, admin_type, geom)
SELECT p.name,
       p.adm0_a3,
       p.type_en,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(p.geom), 3))
FROM raw.ne_10m_admin_1_states_provinces p
JOIN countries c ON c.country_code = p.adm0_a3
WHERE p.name IS NOT NULL;

-- 3c. Validasi
SELECT 'countries' AS tabel, COUNT(*) AS n, SUM((NOT ST_IsValid(geom))::int) AS invalid FROM countries
UNION ALL
SELECT 'provinces', COUNT(*), SUM((NOT ST_IsValid(geom))::int) FROM provinces;
