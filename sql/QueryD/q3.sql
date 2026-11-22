CREATE OR REPLACE VIEW public.v_asian_lake_country_intersections AS
SELECT
    l.lake_id,

    COALESCE(
        NULLIF(BTRIM(l.name), ''),
        'Danau tanpa nama'
    ) AS lake_name,

    l.scalerank,

    ROUND(
        (ST_Area(l.geom::geography) / 1000000.0)::numeric,
        2
    ) AS area_km2,

    COALESCE(
        (
            SELECT STRING_AGG(
                DISTINCT c.name,
                ', ' ORDER BY c.name
            )
            FROM public.countries c
            WHERE c.continent = 'Asia'
              AND ST_Intersects(l.geom, c.geom)
        ),
        'Tidak ada irisan dengan negara Asia'
    ) AS countries_intersected,

    l.geom

FROM public.lakes l

WHERE EXISTS (
    SELECT 1
    FROM public.countries c
    WHERE c.continent = 'Asia'
      AND ST_Intersects(l.geom, c.geom)
);