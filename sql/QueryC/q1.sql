CREATE OR REPLACE VIEW v_top10_density AS

SELECT
    country_id,
    name AS country_name,
    pop_est AS population,
    ROUND(
        (ST_Area(geom::geography) / 1000000.0)::numeric,
        2
    ) AS area_km2,
    ROUND(
        (
            pop_est::numeric /
            NULLIF(
                (ST_Area(geom::geography) / 1000000.0)::numeric,
                0
            )
        ),
        2
    ) AS population_density,
    geom

FROM countries
WHERE pop_est IS NOT NULL
ORDER BY population_density DESC
LIMIT 10;