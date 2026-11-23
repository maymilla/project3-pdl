SELECT ci.geom
FROM cities ci
WHERE EXISTS (
    SELECT 1 FROM rivers r
    WHERE r.name = 'Mekong'
      AND ST_DWithin(ci.geom::geography, r.geom::geography, 50000));