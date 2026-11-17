SELECT co.name, SUM(c.population) AS jumlah_populasi
FROM cities c JOIN countries co ON c.country_code = co.country_code
GROUP BY co.name
ORDER BY jumlah_populasi DESC
LIMIT 10;
