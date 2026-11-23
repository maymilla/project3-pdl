CREATE OR REPLACE VIEW public.v_asia_country_lakes AS
WITH danau_negara AS (
    SELECT
        c.country_id,
        COUNT(DISTINCT l.lake_id) AS jumlah_danau,
        ST_Multi(ST_CollectionExtract(
            ST_Union(ST_Intersection(l.geom, c.geom)), 3
        )) AS geom
    FROM public.countries c
    JOIN public.lakes l ON ST_Intersects(c.geom, l.geom)
    GROUP BY c.country_id
)
SELECT
    c.country_id,
    c.name AS country_name,
    d.jumlah_danau,
    ROUND((ST_Area(d.geom::geography) / 1e6)::numeric, 2)             AS luas_danau_km2,
    ROUND((ST_Area(c.geom::geography) / 1e6)::numeric, 2)             AS luas_negara_km2,
    ROUND((100 * ST_Area(d.geom::geography)
               / ST_Area(c.geom::geography))::numeric, 4)             AS persen_tertutup_danau,
    d.geom::geometry(MultiPolygon, 4326) AS geom
FROM danau_negara d
JOIN public.countries c USING (country_id)
WHERE NOT ST_IsEmpty(d.geom)
ORDER BY persen_tertutup_danau DESC;

SELECT country_id, country_name, jumlah_danau, luas_danau_km2, luas_negara_km2, persen_tertutup_danau
FROM public.v_asia_country_lakes;
