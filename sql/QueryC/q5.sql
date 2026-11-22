CREATE OR REPLACE VIEW public.v_airports_near_large_asian_cities AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY a.airport_id, ci.city_id
    )::bigint AS result_id,

    a.airport_id,
    a.name AS airport_name,
    a.iata_code,

    ci.city_id,
    ci.name AS nearby_city,
    ci.population AS city_population,

    co.name AS country_name,

    ROUND(
        ST_Distance(
            a.geom::geography,
            ci.geom::geography
        )::numeric,
        2
    ) AS distance_m,

    a.geom

FROM public.airports a

JOIN public.cities ci
    ON ST_DWithin(
        a.geom::geography,
        ci.geom::geography,
        50000
    )

JOIN public.countries co
    ON co.country_code = ci.country_code

WHERE co.continent = 'Asia'
  AND ci.population > 1000000;