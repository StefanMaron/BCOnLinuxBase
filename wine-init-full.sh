#!/bin/bash

set -e

echo "=== Full Wine Initialization with .NET Framework ==="

# Set Wine environment
export WINEPREFIX=/opt/wine-prefix
export WINEARCH=win64
export DISPLAY=":0"
export WINEDEBUG=-winediag

# Check if minimal Wine prefix exists
if [ ! -d "$WINEPREFIX/drive_c" ]; then
    echo "Error: Wine prefix not found. Run wine-init-runtime.sh first."
    exit 1
fi

# Start virtual display
echo "Starting virtual display for .NET installation..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    wineserver --kill 2>/dev/null || true
    if [ -n "$XVFB_PID" ]; then
        kill $XVFB_PID 2>/dev/null || true
    fi
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
}
trap cleanup EXIT

# Install .NET Framework 4.8
echo "Installing .NET Framework 4.8..."
winetricks -q dotnet48

# Wait for installation to settle
sleep 5

# Install .NET Desktop Runtime 8.0 directly
echo "Installing .NET Desktop Runtime 8.0..."
cd /tmp
wget -q "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.18/windowsdesktop-runtime-8.0.18-win-x64.exe" || {
    echo "Failed to download .NET Desktop Runtime 8.0"
    exit 1
}

wine windowsdesktop-runtime-8.0.18-win-x64.exe /quiet /install /norestart
rm -f windowsdesktop-runtime-8.0.18-win-x64.exe
echo ".NET Desktop Runtime 8.0 installation completed"

# Enhanced registry configuration
echo "Configuring enhanced registry settings..."
wine reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319" /v "SchUseStrongCrypto" /t REG_DWORD /d 1 /f

echo "✓ Full Wine environment with .NET Framework ready"
echo "Wine prefix: $WINEPREFIX"

# Verify .NET installation
echo "Verifying .NET installation..."
if [ -d "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64" ]; then
    echo "✓ .NET Framework 4.8 installed successfully"
    ls -la "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64/" | head -5
else
    echo "Warning: .NET Framework installation may not be complete"
fi

echo "=== Full initialization completed ==="