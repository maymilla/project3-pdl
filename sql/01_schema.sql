-- Scope: Asia | SRID penyimpanan: EPSG:4326

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS raw;   
DROP TABLE IF EXISTS airports, cities, rivers, lakes, provinces, countries CASCADE;

-- ---------------------------------------------------------------------
-- DDL - tabel final (kontrak skema bersama)
-- ---------------------------------------------------------------------

-- Negara (region) 
CREATE TABLE countries (
    country_id    SERIAL PRIMARY KEY,
    country_code  CHAR(3)      NOT NULL UNIQUE,   -- ADM0_A3 
    iso_a3        VARCHAR(3),                     -- boleh NULL jika sumber = '-99'
    name          VARCHAR(100) NOT NULL,
    continent     VARCHAR(50)  NOT NULL,
    subregion     VARCHAR(50),
    pop_est       BIGINT       CHECK (pop_est >= 0),
    geom          geometry(MultiPolygon, 4326) NOT NULL
);

-- Provinsi / admin-1 (region)
CREATE TABLE provinces (
    province_id   SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    country_code  CHAR(3)      NOT NULL REFERENCES countries(country_code),
    admin_type    VARCHAR(50),                    -- Province, State, Prefecture, ...
    geom          geometry(MultiPolygon, 4326) NOT NULL
);

-- Kota (point) 
CREATE TABLE cities (
    city_id       SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    country_code  CHAR(3)      REFERENCES countries(country_code),
    population    BIGINT       CHECK (population >= 0),
    geom          geometry(Point, 4326) NOT NULL
);

-- Bandara (point)
CREATE TABLE airports (
    airport_id    SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    iata_code     VARCHAR(3),
    geom          geometry(Point, 4326) NOT NULL
);

-- Sungai (polyline) 
CREATE TABLE rivers (
    river_id      SERIAL PRIMARY KEY,
    name          VARCHAR(150),
    scalerank     SMALLINT,
    geom          geometry(MultiLineString, 4326) NOT NULL
);

-- Danau (region) 
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
-- LOAD + CLEANSING dari raw -> final
-- ---------------------------------------------------------------------

-- 3a. Countries: filter Asia
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

-- 3b. Provinces
INSERT INTO provinces (name, country_code, admin_type, geom)
SELECT p.name,
       p.adm0_a3,
       p.type_en,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(p.geom), 3))
FROM raw.ne_10m_admin_1_states_provinces p
JOIN countries c ON c.country_code = p.adm0_a3
WHERE p.name IS NOT NULL;

-- 3c. Cities: hanya kota yang terhubung ke negara Asia
INSERT INTO cities (name, country_code, population, geom)
SELECT p.name,
       p.adm0_a3,
       CASE WHEN p.pop_max >= 0 THEN p.pop_max::BIGINT END,
       p.geom
FROM raw.ne_10m_populated_places p
JOIN countries c ON c.country_code = p.adm0_a3
WHERE p.name IS NOT NULL;

-- 3d. Airports: bandara yang berada di dalam atau pada batas negara Asia
INSERT INTO airports (name, iata_code, geom)
SELECT a.name, a.iata_code, a.geom
FROM raw.ne_10m_airports a
WHERE a.name IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM countries c
      WHERE ST_Covers(c.geom, a.geom)
  );

-- 3e. Rivers: segmen yang beririsan dengan negara Asia
INSERT INTO rivers (name, scalerank, geom)
SELECT r.name,
       r.scalerank::SMALLINT,
       g.geom
FROM raw.ne_10m_rivers_lake_centerlines r
CROSS JOIN LATERAL (
    SELECT ST_Multi(ST_CollectionExtract(ST_MakeValid(r.geom), 2)) AS geom
) g
WHERE NOT ST_IsEmpty(g.geom)
  AND EXISTS (
      SELECT 1
      FROM countries c
      WHERE ST_Intersects(c.geom, g.geom)
  );

-- 3f. Lakes: danau yang beririsan dengan negara Asia
INSERT INTO lakes (name, scalerank, geom)
SELECT l.name,
       l.scalerank::SMALLINT,
       g.geom
FROM raw.ne_10m_lakes l
CROSS JOIN LATERAL (
    SELECT ST_Multi(ST_CollectionExtract(ST_MakeValid(l.geom), 3)) AS geom
) g
WHERE NOT ST_IsEmpty(g.geom)
  AND EXISTS (
      SELECT 1
      FROM countries c
      WHERE ST_Intersects(c.geom, g.geom)
  );

-- 3g. Validasi
SELECT 'countries' AS tabel, COUNT(*) AS n, SUM((NOT ST_IsValid(geom))::int) AS invalid FROM countries
UNION ALL
SELECT 'provinces', COUNT(*), SUM((NOT ST_IsValid(geom))::int) FROM provinces
UNION ALL
SELECT 'cities', COUNT(*), SUM((NOT ST_IsValid(geom))::int) FROM cities
UNION ALL
SELECT 'airports', COUNT(*), SUM((NOT ST_IsValid(geom))::int) FROM airports
UNION ALL
SELECT 'rivers', COUNT(*), SUM((NOT ST_IsValid(geom))::int) FROM rivers
UNION ALL
SELECT 'lakes', COUNT(*), SUM((NOT ST_IsValid(geom))::int) FROM lakes;
