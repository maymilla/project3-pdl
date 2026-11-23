CREATE OR REPLACE VIEW v_perbatasan_darat AS

SELECT
    c.country_id,
    c.name AS country_name,
    c.geom

FROM countries c
WHERE NOT EXISTS (
    SELECT 1
    FROM oceans o
    WHERE ST_Intersects(
        ST_Boundary(c.geom),
        o.geom
    )
)
ORDER BY c.name;
