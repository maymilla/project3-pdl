CREATE OR REPLACE VIEW public.v_asian_city_nearest_river AS
SELECT
    ci.city_id,
    ci.name AS city_name,
    co.name AS country_name,
    ci.population,
    nearest_river.river_name,
    ROUND(
        nearest_river.distance_m::numeric,
        2
    ) AS nearest_river_distance_m,
    ci.geom
FROM public.cities ci
JOIN public.countries co
    ON co.country_code = ci.country_code
LEFT JOIN LATERAL (
    SELECT
        r.name AS river_name,
        ST_Distance(
            ci.geom::geography,
            r.geom::geography
        ) AS distance_m
    FROM public.rivers r
    WHERE r.geom IS NOT NULL
    ORDER BY ST_Distance(
        ci.geom::geography,
        r.geom::geography
    )
    LIMIT 1
) nearest_river ON TRUE
WHERE co.continent = 'Asia';