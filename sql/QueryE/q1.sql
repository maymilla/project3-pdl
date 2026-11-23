CREATE OR REPLACE VIEW public.v_asia_subregion_union AS
WITH sub AS (
    SELECT
        subregion,
        COUNT(*)      AS jumlah_negara,
        SUM(pop_est)  AS total_populasi,
        ST_Multi(ST_Union(geom))::geometry(MultiPolygon, 4326) AS geom
    FROM public.countries
    GROUP BY subregion
)
SELECT
    ROW_NUMBER() OVER (ORDER BY subregion)::int AS id,
    subregion,
    jumlah_negara,
    total_populasi,
    ROUND((ST_Area(geom::geography) / 1e6)::numeric, 2) AS luas_km2,
    geom
FROM sub
ORDER BY subregion;

SELECT id, subregion, jumlah_negara, total_populasi, luas_km2
FROM public.v_asia_subregion_union;
