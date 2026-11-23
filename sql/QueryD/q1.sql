CREATE OR REPLACE VIEW public.v_asian_country_population_area_provinces AS
SELECT
    c.country_id,
    c.country_code,
    c.name AS country_name,
    c.continent,
    c.pop_est AS estimated_population,
    ROUND(
        (ST_Area(c.geom::geography) / 1000000.0)::numeric,
        2
    ) AS area_km2,
    (
        SELECT COUNT(*)
        FROM public.provinces p
        WHERE p.country_code = c.country_code
    ) AS total_provinces,
    c.geom
FROM public.countries c
WHERE c.continent = 'Asia';