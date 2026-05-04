#!/bin/bash

echo --- Started WeGlide import ---

echo Downloading WeGlide
wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64" --header="Accept: application/json" https://api.weglide.org/v1/device -O /ressources/weglide.json

echo Converting json to csv
cat /ressources/weglide.json | jq -r '.[] | {address: .id, registration: .registration, cn: .competition_id, model: .aircraft.name, excluded: .excluded, tracked: .tracked, identified: .identified, updated: .updated} | join(",")' > /ressources/weglide.csv

echo Write import to database
csvsql --db postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@timescaledb:5432/${POSTGRES_DB} --tables weglide_csvkit --no-header-row --insert --overwrite /ressources/weglide.csv

echo Migrate data from import table to final table
read -d '' sql << EOF
    TRUNCATE weglide;
    INSERT INTO weglide (address,registration,cn,model,excluded,tracked,identified,updated)
    SELECT
        ('x' || lpad(w.a, 8, '0'))::bit(32)::int AS address,
        w.b AS registration,
        w.c AS cn,
        w.d AS model,
        w.e AS excluded,
        w.f AS tracked,
        w.g AS identified,
        w.h::TIMESTAMPTZ AS updated
FROM weglide_csvkit AS w;
EOF
psql postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@timescaledb:5432/${POSTGRES_DB} -c "$sql"

echo Refresh materialized view registration_joined
psql postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@timescaledb:5432/${POSTGRES_DB} -c "REFRESH MATERIALIZED VIEW registration_joined;"

echo --- Finished WeGlide import ---
