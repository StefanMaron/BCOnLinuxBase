#!/bin/bash

set -e

echo "Initializing Wine environment with .NET Framework installation..."

# Set Wine environment
export WINEPREFIX=/opt/wine-prefix
export WINEARCH=win64
export DISPLAY=":0"
export WINEDEBUG=-winediag

# Start virtual display for .NET installation
echo "Starting virtual display for Wine initialization..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

# Initialize Wine prefix
echo "Initializing Wine prefix..."
wineboot --init

# Set Wine to Windows 11 mode for better BC compatibility
echo "Setting Wine to Windows 11 mode..."
winecfg /v win11

# Install .NET Framework 4.8 (stable, version-independent base requirement)
echo "Installing .NET Framework 4.8..."
winetricks -q dotnet48

# Configure Wine registry for BC Server compatibility
echo "Configuring Wine registry for BC Server..."
wine reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework" /v "InstallRoot" /t REG_SZ /d "C:\\Windows\\Microsoft.NET\\Framework64\\" /f
wine reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319" /v "SchUseStrongCrypto" /t REG_DWORD /d 1 /f

# Configure graphics settings for headless operation
echo "Configuring graphics settings for headless operation..."
wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v "DirectDrawRenderer" /t REG_SZ /d "opengl" /f
wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v "UseGLSL" /t REG_SZ /d "disabled" /f
wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v "UseVulkan" /t REG_SZ /d "disabled" /f

# Apply Wine culture fixes
echo "Applying Wine culture fixes..."
/usr/local/bin/fix-wine-cultures.sh

# Wait for wineserver to finish
wineserver --wait

# Stop virtual display and clean up
echo "Stopping virtual display..."
kill $XVFB_PID 2>/dev/null || true
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true

echo "Wine initialization completed successfully!"
echo "Wine prefix location: $WINEPREFIX"

# Verify .NET installation
echo "Verifying .NET Framework installation..."
if [ -d "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64" ]; then
    echo "✓ .NET Framework 4.8 installed successfully"
    ls -la "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64/"
else
    echo "✗ .NET Framework 4.8 installation verification failed"
    exit 1
fi

# Install BC Container Helper (requires PowerShell which is already installed)
echo "Installing BC Container Helper..."
pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name BcContainerHelper -Force -AllowClobber -Scope AllUsers"

if [ $? -eq 0 ]; then
    echo "✓ BC Container Helper installed successfully"
else
    echo "✗ BC Container Helper installation failed"
    exit 1
fi

# Verify BC Container Helper installation
echo "Verifying BC Container Helper installation..."
pwsh -Command "Get-Module -ListAvailable BcContainerHelper" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ BC Container Helper verification successful"
else
    echo "✗ BC Container Helper verification failed"
    exit 1
fi

echo "Base image Wine environment ready for BC deployment!"