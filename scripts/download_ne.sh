#!/usr/bin/env bash
# Download dataset Natural Earth 1:10m ke data/raw/ (tidak di-commit).
# Pakai: bash scripts/download_ne.sh [layer ...]   (tanpa argumen = semua layer)
set -euo pipefail
cd "$(dirname "$0")/.."

declare -A CAT=(
  [ne_10m_admin_0_countries]=cultural
  [ne_10m_admin_1_states_provinces]=cultural
  [ne_10m_populated_places]=cultural
  [ne_10m_airports]=cultural
  [ne_10m_rivers_lake_centerlines]=physical
  [ne_10m_lakes]=physical
)
layers=("$@"); [ ${#layers[@]} -eq 0 ] && layers=("${!CAT[@]}")

mkdir -p data/raw
for l in "${layers[@]}"; do
  cat=${CAT[$l]:?"layer tidak dikenal: $l"}
  if [ -d "data/raw/$l" ]; then echo "skip $l (sudah ada)"; continue; fi
  echo "download $l ..."
  curl -fsSL -o "data/raw/$l.zip" "https://naciscdn.org/naturalearth/10m/$cat/$l.zip"
  mkdir -p "data/raw/$l" && unzip -oq "data/raw/$l.zip" -d "data/raw/$l" && rm "data/raw/$l.zip"
done
