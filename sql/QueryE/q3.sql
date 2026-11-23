CREATE OR REPLACE VIEW public.v_asia_bigcity_hull AS
WITH kota_besar AS (
    SELECT
        ci.country_code,
        COUNT(*)              AS jumlah_kota,
        SUM(ci.population)    AS total_populasi_kota,
        ST_ConvexHull(ST_Collect(ci.geom)) AS hull
    FROM public.cities ci
    WHERE ci.population >= 500000
    GROUP BY ci.country_code
    HAVING COUNT(*) >= 3
)
SELECT
    c.country_id,
    c.name AS country_name,
    k.jumlah_kota,
    k.total_populasi_kota,
    ROUND((ST_Area(k.hull::geography) / 1e6)::numeric, 2) AS luas_cakupan_km2,
    k.hull::geometry(Polygon, 4326) AS geom
FROM kota_besar k
JOIN public.countries c USING (country_code)
WHERE GeometryType(k.hull) = 'POLYGON'
ORDER BY luas_cakupan_km2 DESC;

SELECT country_id, country_name, jumlah_kota, total_populasi_kota, luas_cakupan_km2
FROM public.v_asia_bigcity_hull;
