#!/usr/bin/env bash
# Dump tabel final (hanya schema public) ke dumps/pdl.dump untuk dibagikan.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash: jangan ubah /data/... jadi C:/Program Files/Git/...
cd "$(dirname "$0")/.."
out=${1:-dumps/pdl.dump}
docker compose exec -T db pg_dump -U postgres -d pdl -Fc --no-owner -n public > "$out"
echo "dump -> $out ($(du -h "$out" | cut -f1))"
