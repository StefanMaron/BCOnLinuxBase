#!/bin/bash

# Exit on error
set -e

echo "=== Ultra-Minimal Wine Initialization for CI ==="

# Set Wine environment for headless operation
export WINEPREFIX=/root/.local/share/wineprefixes/bc1
export WINEARCH=win64
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mshtml,mscoree,oleaut32,rpcrt4,wininet="

# Critical: Set Wine library paths for wine64-bc4ubuntu package
export PATH="/usr/local/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib:/usr/local/lib/wine/x86_64-unix:/usr/local/lib/wine:${LD_LIBRARY_PATH}"
export WINEDLLPATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib/wine/x86_64-windows"
export WINELOADER="/usr/local/bin/wine"
export WINESERVER="/usr/local/bin/wineserver"

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

# Initialize Wine prefix with wineboot
echo "Initializing Wine prefix at $WINEPREFIX..."
# Suppress errors that are actually just warnings, give it time to complete
timeout 60 wineboot --init 2>&1 | grep -v "wine: Call from" | grep -v "wine: Unimplemented" | grep -v "wine: could not load" | grep -v "starting debugger" || true

# Give Wine a moment to finish writing files
sleep 3

# Verify prefix structure
if [ -d "$WINEPREFIX/drive_c" ]; then
    echo "✓ Wine prefix initialized successfully"
    ls -la "$WINEPREFIX/drive_c/" | head -5
else
    echo "✗ Wine prefix initialization failed"
    exit 1
fi

# Test Wine functionality without GUI
echo "Testing Wine functionality..."
if wine --version >/dev/null 2>&1; then
    echo "✓ Wine is functional: $(wine --version)"
else
    echo "Warning: Wine version check failed, but prefix exists"
fi

# Apply culture fixes if available (non-interactive)
if [ -f "/usr/local/bin/fix-wine-cultures.sh" ]; then
    echo "Applying Wine culture fixes..."
    timeout 30 /usr/local/bin/fix-wine-cultures.sh 2>/dev/null || echo "Culture fixes completed with warnings"
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
echo "✓ Ultra-minimal Wine environment initialized"
echo "Wine prefix: $WINEPREFIX"
echo "Wine version: $(wine --version 2>/dev/null || echo 'unknown')"
echo ""
echo "This is a minimal Wine setup suitable for CI/CD pipelines."
echo "For full .NET Framework support, run:"
echo "  /usr/local/bin/wine-init-full.sh"
echo ""
echo "=== Base image ready for Business Central deployment ==="