#!/bin/bash
# Flatten sshadows/wine-bc base image to reduce layer count
# This creates a single-layer version of the base image

set -e

echo "=== Flattening Wine BC Base Image ==="
echo ""
echo "Original base image: sshadows/wine-bc:latest"
docker inspect sshadows/wine-bc:latest --format='Layers: {{len .RootFS.Layers}}'
docker images sshadows/wine-bc:latest --format='Size: {{.Size}}'
echo ""

echo "Creating temporary container..."
docker create --name wine-flatten-temp sshadows/wine-bc:latest

echo "Exporting container filesystem (this takes ~1 minute)..."
docker export wine-flatten-temp | docker import \
  --change 'ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
  --change 'ENV WINEPREFIX=/root/.local/share/wineprefixes/bc1' \
  --change 'ENV WINEDEBUG=-all' \
  --change 'WORKDIR /' \
  --change 'CMD ["wine64" "cmd"]' \
  - sshadows/wine-bc:flat

echo "Cleaning up temporary container..."
docker rm wine-flatten-temp

echo ""
echo "=== Flattened Image Created ==="
echo "New flattened image: sshadows/wine-bc:flat"
docker inspect sshadows/wine-bc:flat --format='Layers: {{len .RootFS.Layers}}'
docker images sshadows/wine-bc:flat --format='Size: {{.Size}}'
echo ""
echo "Layer reduction: 8 layers → 1 layer"
echo ""
echo "You can now use this in your Dockerfile with:"
echo "FROM sshadows/wine-bc:flat"
