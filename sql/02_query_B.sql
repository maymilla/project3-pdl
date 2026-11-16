-- B1. Bagaimana geometri wilayah negara-negara yang berbatasan langsung
--     dengan Tiongkok?
SELECT c.geom
FROM countries c
WHERE ST_Touches(c.geom, (SELECT geom FROM countries WHERE country_code = 'CHN'));

