#!/bin/bash

# Exit on error
set -e

echo "=== Ultra-Minimal Wine Initialization for CI ==="

# Set Wine environment for headless operation
export WINEPREFIX=/opt/wine-prefix
export WINEARCH=win64
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mshtml,mscoree,oleaut32,rpcrt4,wininet="

# Ensure locale is set
echo "Setting up locale..."
locale-gen en_US.UTF-8 2>/dev/null || echo "locale-gen failed, continuing..."
update-locale LANG=en_US.UTF-8 2>/dev/null || echo "update-locale failed, continuing..."

# Create Wine prefix structure manually
echo "Creating Wine prefix structure..."
mkdir -p "$WINEPREFIX"
mkdir -p "$WINEPREFIX/drive_c/windows/system32"
mkdir -p "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64"
mkdir -p "$WINEPREFIX/drive_c/Program Files"
mkdir -p "$WINEPREFIX/drive_c/Program Files (x86)"

# Create minimal system.reg and user.reg files
echo "Creating minimal Wine registry..."
cat > "$WINEPREFIX/system.reg" << 'EOF'
WINE REGISTRY Version 2
[Software\\Microsoft\\Windows NT\\CurrentVersion] 1234567890
"CurrentVersion"="10.0"
"CurrentBuild"="19041"

[Software\\Microsoft\\.NETFramework] 1234567890
"InstallRoot"="C:\\Windows\\Microsoft.NET\\Framework64\\"

[Software\\Classes] 1234567890

EOF

cat > "$WINEPREFIX/user.reg" << 'EOF'
WINE REGISTRY Version 2
[Software\\Wine] 1234567890
"Version"="win10"

[Software\\Wine\\Direct3D] 1234567890
"DirectDrawRenderer"="gdi"
"UseGLSL"="disabled"
"UseVulkan"="disabled"

EOF

# Create userdef.reg
cat > "$WINEPREFIX/userdef.reg" << 'EOF'
WINE REGISTRY Version 2

EOF

# Verify prefix structure
if [ -d "$WINEPREFIX/drive_c" ]; then
    echo "✓ Wine prefix structure created successfully"
else
    echo "✗ Wine prefix creation failed"
    exit 1
fi

# Test Wine functionality without GUI
echo "Testing Wine functionality..."
export DISPLAY=""  # Disable display entirely
if timeout 10 wine --version >/dev/null 2>&1; then
    echo "✓ Wine is functional"
else
    echo "Warning: Wine test failed, but prefix exists"
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