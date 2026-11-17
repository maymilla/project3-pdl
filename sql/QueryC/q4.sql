CREATE OR REPLACE VIEW v_most_airports AS

SELECT
    c.country_id,
    c.name AS country_name,
    COUNT(DISTINCT a.airport_id) AS total_airports
FROM countries c
LEFT JOIN airports a
    ON ST_Covers(c.geom, a.geom)
GROUP BY
    c.country_id,
    c.name,
    c.geom
ORDER BY
    total_airports DESC
LIMIT 5;
