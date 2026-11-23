SELECT c.geom
FROM countries c
WHERE ST_Touches(c.geom, (SELECT geom FROM countries WHERE country_code = 'CHN'));