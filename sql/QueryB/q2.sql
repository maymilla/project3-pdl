SELECT p.geom
FROM provinces p
WHERE ST_Touches(p.geom, (SELECT geom FROM provinces WHERE name = 'Kalimantan Timur'))
  AND p.name <> 'Kalimantan Timur';
