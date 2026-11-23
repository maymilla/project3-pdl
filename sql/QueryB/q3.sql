SELECT ST_Intersection(r.geom, c.geom) AS geom
FROM rivers r, countries c
WHERE c.country_code = 'IDN' AND ST_Intersects(r.geom, c.geom);