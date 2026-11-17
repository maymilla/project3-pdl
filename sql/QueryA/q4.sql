SELECT co.name, c.name, c.population
FROM cities c JOIN countries co ON co.country_code = c.country_code
ORDER BY c.population DESC
LIMIT 10;
