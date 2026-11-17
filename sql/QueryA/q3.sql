SELECT co.name, COUNT(c.name) AS jumlah_kota
FROM countries co JOIN cities c ON co.country_code = c.country_code
GROUP BY co.name
ORDER BY jumlah_kota DESC;
