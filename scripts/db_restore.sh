#!/usr/bin/env bash
# Restore dump ke database pdl. PERHATIAN: database pdl yang ada DIHAPUS dulu.
# Pakai: bash scripts/db_restore.sh [dumps/pdl.dump]
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash: jangan ubah /data/... jadi C:/Program Files/Git/...
cd "$(dirname "$0")/.."
in=${1:-dumps/pdl.dump}
[ -f "$in" ] || { echo "file $in tidak ada"; exit 1; }

docker compose up -d --wait db
docker compose exec -T db dropdb   -U postgres --if-exists --force pdl
docker compose exec -T db createdb -U postgres -T template0 pdl
docker compose exec -T db psql -U postgres -d pdl -qc "CREATE EXTENSION postgis; CREATE SCHEMA raw;"
docker compose exec -T db pg_restore -U postgres -d pdl --no-owner -n public < "$in"
docker compose exec -T db psql -U postgres -d pdl -c "\dt public.*"
