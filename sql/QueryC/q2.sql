CREATE OR REPLACE VIEW v_rivers_multiple_countries AS

SELECT
    r.name as river_name,
    COUNT(DISTINCT c.country_id) AS total_countries,
    STRING_AGG(
        DISTINCT c.name,
        ', ' ORDER BY c.name
    ) AS countries,
    r.geom
FROM(
    SELECT  
        name,
        ST_UnaryUnion(ST_Collect(geom)) AS geom
    FROM rivers
    WHERE name IS NOT NULL AND BTRIM(name) <> ''
    GROUP BY name
) r

JOIN countries c ON ST_Intersects(r.geom, c.geom)
GROUP BY r.name, r.geom
HAVING COUNT(DISTINCT c.country_id) >= 2
ORDER BY total_countries DESC, river_name;