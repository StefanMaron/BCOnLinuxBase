#!/bin/bash

set -e

echo "=== Full Wine Initialization with .NET 8 Runtime ==="

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

# Set Wine environment
export WINEPREFIX=/root/.local/share/wineprefixes/bc1
export WINEARCH=win64
export DISPLAY=":0"
export WINEDEBUG=-all

# Set Wine environment paths
export PATH="/usr/local/bin:${PATH}"
export WINELOADER="/usr/local/bin/wine"
export WINESERVER="/usr/local/bin/wineserver"

# Start virtual display (needed for .NET installation)
echo "Starting virtual display..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX &
XVFB_PID=$!
sleep 3

# Note: Wine prefix will be automatically initialized by the .NET installers

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

# .NET Framework 4.8 installation disabled per user request
# echo "Installing .NET Framework 4.8..."
# winetricks -q dotnet48
echo "Skipping .NET Framework 4.8 installation (disabled)"

# Test network connectivity
echo "Testing network connectivity..."
if ! wget -q --spider https://dotnet.microsoft.com 2>/dev/null; then
    echo "Warning: Cannot reach dotnet.microsoft.com - checking network..."
    wget --version | head -1
    ping -c 1 8.8.8.8 2>/dev/null || echo "Network connectivity issue detected"
fi


# Install .NET Desktop Runtime 8.0 using winetricks (required for BC v26)
echo "Installing .NET Desktop Runtime 8.0 with winetricks..."
winetricks -q dotnet8 dotnetdesktop8

# Install .NET 8.0.18 Hosting Bundle (includes all runtimes needed for BC)
echo "Installing .NET 8.0.18 Hosting Bundle..."
cd /tmp

# Download the hosting bundle which includes:
# - ASP.NET Core Runtime
# - .NET Runtime
# - IIS support modules
wget -q "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/8.0.18/dotnet-hosting-8.0.18-win.exe" || {
    echo "Failed to download .NET 8.0.18 Hosting Bundle"
    exit 1
}

wine dotnet-hosting-8.0.18-win.exe /quiet /install /norestart
rm -f dotnet-hosting-8.0.18-win.exe
echo ".NET 8.0.18 Hosting Bundle installation completed"

# Also install Desktop Runtime for BC compatibility
echo "Installing .NET Desktop Runtime 8.0..."
wget -q "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.18/windowsdesktop-runtime-8.0.18-win-x64.exe" || {
    echo "Failed to download .NET Desktop Runtime 8.0"
    exit 1
}

wine windowsdesktop-runtime-8.0.18-win-x64.exe /quiet /install /norestart
rm -f windowsdesktop-runtime-8.0.18-win-x64.exe
echo ".NET Desktop Runtime 8.0 installation completed"

# Install ASP.NET Core Runtime 8.0 (required for BC v26 Dev endpoints)
echo "Installing ASP.NET Core Runtime 8.0..."

# Use the direct Microsoft CDN URL
ASPNET_CORE_URL="https://download.visualstudio.microsoft.com/download/pr/3bebb4ec-ed65-47e9-a0d1-949984bfa48f/0f8cecf7f99c3b0e4a3ef088c1c1c850/aspnetcore-runtime-8.0.11-win-x64.exe"
echo "Downloading ASP.NET Core Runtime 8.0..."
echo "URL: $ASPNET_CORE_URL"

if ! wget --timeout=30 --tries=3 --no-check-certificate --progress=dot:giga "$ASPNET_CORE_URL" -O aspnetcore-runtime-8.0.11-win-x64.exe; then
    echo "Primary download failed, trying fallback URL..."
    # Try the latest stable version as fallback
    FALLBACK_URL="https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/8.0.11/aspnetcore-runtime-8.0.11-win-x64.exe"
    if ! wget --timeout=30 --tries=3 --no-check-certificate --progress=dot:giga "$FALLBACK_URL" -O aspnetcore-runtime-8.0.11-win-x64.exe; then
        echo "ERROR: Could not download ASP.NET Core Runtime 8.0"
        echo "Please check network connectivity or download manually"
        exit 1
    fi
fi

# Use the Wine executable with proper environment
echo "Installing with Wine (environment set)..."
ASPNET_INSTALL_OUTPUT=$(/usr/local/bin/wine aspnetcore-runtime-8.0.11-win-x64.exe /quiet /install /norestart 2>&1 || true)
check_wine_error "$ASPNET_INSTALL_OUTPUT" "ASP.NET Core Runtime installer"
rm -f aspnetcore-runtime-8.0.11-win-x64.exe
echo "ASP.NET Core Runtime 8.0 installation completed"

# Wait for installations to settle
sleep 5

# Enhanced registry configuration for .NET
echo "Configuring registry settings for .NET..."
REG_OUTPUT1=$(/usr/local/bin/wine reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework" /v "InstallRoot" /t REG_SZ /d "C:\\Windows\\Microsoft.NET\\Framework64\\" /f 2>&1 || true)
check_wine_error "$REG_OUTPUT1" "registry configuration"
REG_OUTPUT2=$(/usr/local/bin/wine reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETCore" /v "InstallRoot" /t REG_SZ /d "C:\\Program Files\\dotnet\\" /f 2>&1 || true)
check_wine_error "$REG_OUTPUT2" "registry configuration"
# Enable strong crypto for any .NET Framework components that might exist
REG_OUTPUT3=$(/usr/local/bin/wine reg add "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319" /v "SchUseStrongCrypto" /t REG_DWORD /d 1 /f 2>&1 || true)
check_wine_error "$REG_OUTPUT3" "registry configuration"

echo "✓ Full Wine environment with .NET 8 Runtime ready"
echo "Wine prefix: $WINEPREFIX"

# Verify .NET 8 installation
echo "Verifying .NET 8 installation..."
DOTNET_CHECK_OUTPUT=$(/usr/local/bin/wine cmd /c "dotnet --list-runtimes" 2>&1 || true)
check_wine_error "$DOTNET_CHECK_OUTPUT" "dotnet verification"
if echo "$DOTNET_CHECK_OUTPUT" | grep -q "Microsoft"; then
    echo "✓ .NET 8 runtimes installed successfully"
    echo "$DOTNET_CHECK_OUTPUT"
else
    echo "Note: .NET CLI verification through Wine may not work, checking directories..."
    if [ -d "$WINEPREFIX/drive_c/Program Files/dotnet" ]; then
        echo "✓ .NET 8 directory structure exists"
        ls -la "$WINEPREFIX/drive_c/Program Files/dotnet/" 2>/dev/null | head -5 || true
    fi
fi

echo "=== Full initialization completed ==="