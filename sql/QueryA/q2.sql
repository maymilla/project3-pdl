SELECT co.name, COUNT(p.name) AS jumlah_provinsi
FROM countries co JOIN provinces p ON co.country_code = p.country_code
GROUP BY co.name
ORDER BY jumlah_provinsi DESC
LIMIT 5;
