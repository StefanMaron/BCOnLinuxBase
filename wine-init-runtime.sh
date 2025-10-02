#!/bin/bash

# Exit on error
set -e

echo "=== Wine Runtime Configuration for CI ==="

# Function to check for critical Wine errors
check_wine_error() {
    local output="$1"
    local command_name="$2"
    if echo "$output" | grep -q "wine: could not load kernel32.dll"; then
        echo "✗ FATAL: Wine failed to load kernel32.dll during $command_name"
        echo "Wine is broken and cannot initialize properly"
        echo "Error output:"
        echo "$output"
        exit 1
    fi
}

# Set Wine environment for headless operation
export WINEPREFIX=/root/.local/share/wineprefixes/bc1
export WINEARCH=win64
export WINEDEBUG=-all
#export WINEDLLOVERRIDES="mshtml,mscoree,oleaut32,rpcrt4,wininet="

# Set Wine environment paths
#export PATH="/usr/local/bin:${PATH}"
#export WINELOADER="/usr/local/bin/wine"
#export WINESERVER="/usr/local/bin/wineserver"

# Start virtual display (required for Wine operations)
echo "Starting virtual display..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX &
XVFB_PID=$!
export DISPLAY=":0"
sleep 2

# Ensure locale is set
echo "Setting up locale..."
locale-gen en_US.UTF-8 2>/dev/null || echo "locale-gen failed, continuing..."
update-locale LANG=en_US.UTF-8 2>/dev/null || echo "update-locale failed, continuing..."

# Verify prefix structure (base image already initialized)
if [ -d "$WINEPREFIX/drive_c" ]; then
    echo "✓ Wine prefix verified from base image"
    ls -la "$WINEPREFIX/drive_c/" | head -5
else
    echo "✗ Wine prefix not found - base image may be corrupted"
    exit 1
fi

# Test Wine functionality without GUI
echo "Testing Wine functionality..."
WINE_VERSION_OUTPUT=$(wine --version 2>&1 || true)
check_wine_error "$WINE_VERSION_OUTPUT" "wine --version"
if echo "$WINE_VERSION_OUTPUT" | grep -q "wine"; then
    echo "✓ Wine is functional: $(echo "$WINE_VERSION_OUTPUT" | head -1)"
else
    echo "Warning: Wine version check failed, but prefix exists"
fi

# Apply culture fixes if available (non-interactive)
if [ -f "/usr/local/bin/fix-wine-cultures.sh" ]; then
    echo "Applying Wine culture fixes..."
    CULTURE_OUTPUT=$(timeout 30 /usr/local/bin/fix-wine-cultures.sh 2>&1 || echo "Culture fixes completed with warnings")
    check_wine_error "$CULTURE_OUTPUT" "fix-wine-cultures.sh"
    echo "$CULTURE_OUTPUT" | tail -5
fi

# Install BC Container Helper (essential for BC functionality)
echo "Installing BC Container Helper..."
if timeout 90 pwsh -Command "
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue;
    Install-Module -Name BcContainerHelper -Force -AllowClobber -Scope AllUsers -ErrorAction SilentlyContinue
" 2>/dev/null; then
    echo "✓ BC Container Helper installed successfully"
else
    echo "Warning: BC Container Helper installation timed out or failed"
fi

# Final verification
echo "✓ Wine runtime environment configured"
echo "Wine prefix: $WINEPREFIX"
echo "Wine version: $(wine --version 2>/dev/null || echo 'unknown')"
echo Now starting full initialization...
echo ""
/usr/local/bin/wine-init-full.sh
