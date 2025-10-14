# Start with Wine BC base image
ARG BASE_IMAGE_TAG=latest
FROM sshadows/wine-bc:${BASE_IMAGE_TAG}

# Download Wine, install all dependencies, and Microsoft tools in single layer
# GitHub Actions optimization: Combine package installation with BC Container Helper
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Download tools
        wget \
        curl \
        ca-certificates \
        gnupg2 \
        # Required tools (NEW packages not in wine-bc base)
        winbind \
        p7zip-full \
        net-tools \
        cabextract \
        software-properties-common \
        xvfb \
        xauth \
        unzip \
        locales \
        # Additional tools
        lsb-release \
        vim-common \
        # SQL Server tools dependencies
        apt-transport-https \
        # Network debugging tools
        iputils-ping \
        dnsutils \
        telnet \
    && wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks \
    && chmod +x /usr/bin/winetricks \
    && wget -q "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" -O /tmp/ms-prod.deb \
    && dpkg -i /tmp/ms-prod.deb \
    && rm /tmp/ms-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell dotnet-runtime-8.0 \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-tools18 unixodbc-dev \
    && echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bash.bashrc \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name BcContainerHelper -Force -AllowClobber -Scope AllUsers" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
           /tmp/* \
           /var/tmp/* \
           /var/cache/apt/archives/* \
           /usr/share/doc/* \
           /usr/share/man/* \
           ~/.cache \
           /root/.cache

# Set Wine environment
ENV PATH="/usr/local/bin:${PATH}" \
    WINEPREFIX=/root/.local/share/wineprefixes/bc1 \
    DEBIAN_FRONTEND=noninteractive \
    DISPLAY=":0" \
    WINE_SKIP_GECKO_INSTALLATION=1 \
    WINE_SKIP_MONO_INSTALLATION=1 \
    WINEDEBUG=-all

# Copy scripts and set permissions in single layer
COPY fix-wine-cultures.sh test-wine.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/fix-wine-cultures.sh /usr/local/bin/test-wine.sh

# ============================================================================
# Initialize .NET components during IMAGE BUILD (not runtime)
# Combined .NET 8 + Framework 4.8 installation in single layer for GitHub Actions
# This reduces layer count and enables better cleanup
# ============================================================================
RUN echo "=== Installing .NET 8 and Framework 4.8 (build-time initialization) ===" && \
    # Verify Wine prefix inherited from base image
    test -d "$WINEPREFIX/drive_c" && echo "✓ Wine prefix inherited from base image" || exit 1 && \
    \
    # Start temporary Xvfb for all .NET installations
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true && \
    export DISPLAY=":0" && \
    export XKB_DEFAULT_LAYOUT=us && \
    Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX & \
    XVFB_PID=$! && \
    sleep 3 && \
    \
    # Apply BC culture fixes (BC-specific Wine patches)
    echo "Applying BC culture fixes..." && \
    /usr/local/bin/fix-wine-cultures.sh && \
    \
    # Install .NET 8.0.18 Hosting Bundle (ASP.NET Core + Runtime)
    echo "Installing .NET 8.0.18 Hosting Bundle..." && \
    cd /tmp && \
    wget -q "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/8.0.18/dotnet-hosting-8.0.18-win.exe" && \
    wine dotnet-hosting-8.0.18-win.exe /quiet /install /norestart && \
    rm -f dotnet-hosting-8.0.18-win.exe && \
    \
    # Install .NET 8.0.12 Desktop Runtime (WPF/WinForms support)
    echo "Installing .NET Desktop Runtime 8.0.12..." && \
    wget -q "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.12/windowsdesktop-runtime-8.0.12-win-x64.exe" && \
    wine windowsdesktop-runtime-8.0.12-win-x64.exe /quiet /install /norestart && \
    rm -f windowsdesktop-runtime-8.0.12-win-x64.exe && \
    \
    # Configure .NET registry paths
    echo "Configuring .NET registry settings..." && \
    wine reg add "HKLM\\SOFTWARE\\Microsoft\\.NETCore" /v "InstallRoot" /t REG_SZ /d "C:\\Program Files\\dotnet\\" /f && \
    wine reg add "HKLM\\SOFTWARE\\Microsoft\\.NETFramework" /v "InstallRoot" /t REG_SZ /d "C:\\Windows\\Microsoft.NET\\Framework64\\" /f && \
    wine reg add "HKLM\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319" /v "SchUseStrongCrypto" /t REG_DWORD /d 1 /f && \
    \
    # Configure Wine graphics for headless operation
    wine reg add "HKCU\\Software\\Wine\\Direct3D" /v "DirectDrawRenderer" /t REG_SZ /d "opengl" /f && \
    wine reg add "HKCU\\Software\\Wine\\Direct3D" /v "UseGLSL" /t REG_SZ /d "disabled" /f && \
    wine reg add "HKCU\\Software\\Wine\\Direct3D" /v "UseVulkan" /t REG_SZ /d "disabled" /f && \
    \
    # Install .NET Framework 4.8 using winetricks
    echo "Installing .NET Framework 4.8 (this may take 5-10 minutes)..." && \
    WINEDLLPATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib/wine/x86_64-windows" \
    LD_LIBRARY_PATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib:${LD_LIBRARY_PATH}" \
    winetricks prefix=bc1 -q dotnet48 && \
    \
    # Cleanup Wine processes and temp files
    wineserver --kill && \
    kill $XVFB_PID 2>/dev/null || true && \
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 && \
    \
    # Aggressive cleanup of Wine installation artifacts
    rm -rf /tmp/* \
           /var/tmp/* \
           ~/.cache/wine \
           ~/.cache/winetricks \
           "$WINEPREFIX/drive_c/users/root/Temp"/* \
           "$WINEPREFIX/drive_c/windows/Installer"/* \
           "$WINEPREFIX/drive_c/windows/temp"/* && \
    \
    # Verify installations
    test -d "$WINEPREFIX/drive_c/Program Files/dotnet" && echo "✓ .NET 8 installed successfully" || exit 1 && \
    test -d "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319" && echo "✓ .NET Framework 4.8 installed successfully" || exit 1 && \
    \
    # Create marker file and directories
    touch /home/.wine-initialized && \
    mkdir -p /home/bcartifacts /home/bcserver/Keys /home/scripts /home/tests && \
    \
    # Show Wine version
    echo "Wine version installed:" && wine --version

# Default command - Wine and .NET are already initialized, just start shell
CMD ["/bin/bash"]