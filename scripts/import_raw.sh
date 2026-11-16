#!/usr/bin/env bash
# Import shapefile dari data/raw/<layer>/ ke tabel raw.<layer> (pakai container GDAL).
# Pakai: bash scripts/import_raw.sh ne_10m_admin_0_countries ne_10m_admin_1_states_provinces
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash: jangan ubah /data/... jadi C:/Program Files/Git/...
cd "$(dirname "$0")/.."
[ $# -gt 0 ] || { echo "pakai: $0 <layer> [layer ...]"; exit 1; }

docker compose up -d --wait db
docker compose exec -T db psql -U postgres -d pdl -qc "CREATE SCHEMA IF NOT EXISTS raw;"

for l in "$@"; do
  case $l in
    *populated_places|*airports) nlt=() ;;              # point tetap Point
    *) nlt=(-nlt PROMOTE_TO_MULTI) ;;                    # polygon/line -> Multi*
  esac
  echo "import $l -> raw.$l"
  docker compose run --rm gdal ogr2ogr -f PostgreSQL \
    "PG:host=db dbname=pdl user=postgres password=postgres" \
    "/data/$l/$l.shp" \
    -nln "raw.$l" -overwrite -lco GEOMETRY_NAME=geom -lco FID=gid \
    -t_srs EPSG:4326 "${nlt[@]}"
done
