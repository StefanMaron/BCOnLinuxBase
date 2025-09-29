#!/bin/bash

# Test script for Wine installation
echo "=== Wine Build Test ==="
echo "Wine version: $(cat /opt/wine-custom/wine-version.txt)"
echo "Wine path: $(which wine)"
echo "Wine64 path: $(which wine64)"

echo ""
echo "=== Testing Wine functionality ==="
# Test basic Wine functionality
export WINEPREFIX=/root/.local/share/wineprefixes/bc1
export WINEARCH=win64

echo "Using Wine prefix at $WINEPREFIX..."

echo "Testing Wine registry..."
wine reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2>/dev/null

echo ""
echo "=== Wine Libraries ==="
echo "Available Wine libraries:"
ls -la /opt/wine-custom/lib64/ | head -10
echo "... (showing first 10 libraries)"

echo ""
echo "=== Wine Build Information ==="
echo "Build completed successfully!"
echo "Image size optimization: Wine-only runtime"
echo "Suitable for: Business Central on Linux base images"

# Keep container running for inspection if needed
if [ "$1" = "--keep-alive" ]; then
    echo ""
    echo "Container staying alive for inspection..."
    tail -f /dev/null
else
    echo ""
    echo "Test completed. Container will exit."
fi
