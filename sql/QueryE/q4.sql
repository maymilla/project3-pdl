CREATE OR REPLACE VIEW public.v_asia_airport_coverage AS
WITH bandara_negara AS (
    SELECT
        c.country_id,
        COUNT(*) AS jumlah_bandara,
        ST_Union(ST_Buffer(a.geom::geography, 100000)::geometry) AS zona
    FROM public.countries c
    JOIN public.airports a ON ST_Covers(c.geom, a.geom)
    GROUP BY c.country_id
),
terpotong AS (
    SELECT
        b.country_id,
        b.jumlah_bandara,
        ST_Multi(ST_CollectionExtract(ST_Intersection(b.zona, c.geom), 3)) AS geom
    FROM bandara_negara b
    JOIN public.countries c USING (country_id)
)
SELECT
    c.country_id,
    c.name AS country_name,
    t.jumlah_bandara,
    ROUND((ST_Area(t.geom::geography) / 1e6)::numeric, 2)  AS luas_terjangkau_km2,
    ROUND((ST_Area(c.geom::geography) / 1e6)::numeric, 2)  AS luas_negara_km2,
    ROUND((100 * ST_Area(t.geom::geography)
               / ST_Area(c.geom::geography))::numeric, 2)  AS persen_terjangkau,
    t.geom::geometry(MultiPolygon, 4326) AS geom
FROM terpotong t
JOIN public.countries c USING (country_id)
ORDER BY persen_terjangkau DESC;

SELECT country_id, country_name, jumlah_bandara, luas_terjangkau_km2, luas_negara_km2, persen_terjangkau
FROM public.v_asia_airport_coverage;
