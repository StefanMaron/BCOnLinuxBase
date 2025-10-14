# Start with Wine BC base image
ARG BASE_IMAGE_TAG=latest
FROM sshadows/wine-bc:${BASE_IMAGE_TAG}

# Download Wine, install all dependencies, and Microsoft tools in single layer
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Download tools
        wget \
        curl \
        ca-certificates \
        gnupg2 \
        # Wine runtime dependencies - REMOVED (inherited from wine-bc base image)
        # The following packages are already installed in sshadows/wine-bc:
        # - All X11 libraries (libx11-6, libfreetype6, libxcursor1, libxi6, libxext6, etc.)
        # - All graphics libraries (libgl1, libglu1-mesa, libxrandr2, libxrender1, libxinerama1)
        # - All audio libraries (libasound2, libpulse0)
        # - All system libraries (libdbus-1-3, libgnutls30, libncurses6, libcups2)
        # - Kerberos libraries (libkrb5-3, libgssapi-krb5-2, etc.)
        # See /home/sshadows/wine/Dockerfile.optimized:159-212 for complete list
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
    # && wget -q "https://github.com/SShadowS/wine64-bc4ubuntu/releases/latest/download/wine-custom_10.15-unknown_amd64.deb" -O /tmp/wine-custom.deb \
    # && apt-get install -y /tmp/wine-custom.deb \
    # && rm /tmp/wine-custom.deb \
    # && chmod +x /usr/local/lib/wine/x86_64-unix/wine-preloader /usr/local/lib/wine/x86_64-unix/wine64-preloader 2>/dev/null || true \
    # && chmod +x /usr/local/lib/wine/i386-unix/wine-preloader 2>/dev/null || true \
    && wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks \
    && chmod +x /usr/bin/winetricks \
    && wget -q "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell dotnet-runtime-8.0 \
    && ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev \
    && echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bash.bashrc \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure dynamic linker for Wine libraries - must be after Wine extraction
# RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wine.conf && \
#     echo "/usr/local/lib/wine" >> /etc/ld.so.conf.d/wine.conf && \
#     echo "/usr/local/lib/wine/x86_64-unix" >> /etc/ld.so.conf.d/wine.conf && \
#     ldconfig -v 2>&1 | grep -E "^/usr/local" || true && \
#     ldconfig

# Set Wine environment
ENV PATH="/usr/local/bin:${PATH}" \
    # WINEARCH=win64 \
    WINEPREFIX=/root/.local/share/wineprefixes/bc1 \
    DEBIAN_FRONTEND=noninteractive \
    DISPLAY=":0" \
    WINE_SKIP_GECKO_INSTALLATION=1 \
    WINE_SKIP_MONO_INSTALLATION=1 \
    WINEDEBUG=-all

# Install BC Container Helper during build for artifact download
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name BcContainerHelper -Force -AllowClobber -Scope AllUsers"

# Copy Wine culture fix script BEFORE we use it in the .NET installation
COPY fix-wine-cultures.sh /usr/local/bin/fix-wine-cultures.sh
RUN chmod +x /usr/local/bin/fix-wine-cultures.sh

# ============================================================================
# Initialize .NET components during IMAGE BUILD (not runtime)
# This makes containers start in seconds instead of minutes
# Wine prefix is already initialized in base image (wine/Dockerfile.optimized:237)
# ============================================================================
RUN echo "=== Installing .NET 8 for BC v26 (build-time initialization) ===" && \
    # Verify Wine prefix inherited from base image
    test -d "$WINEPREFIX/drive_c" && echo "✓ Wine prefix inherited from base image" || exit 1 && \
    \
    # Start temporary Xvfb for .NET installation
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
    # Cleanup
    wineserver --kill && \
    kill $XVFB_PID 2>/dev/null || true && \
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 && \
    \
    # Verify installation
    test -d "$WINEPREFIX/drive_c/Program Files/dotnet" && echo "✓ .NET 8 installed successfully" || exit 1 && \
    ls -la "$WINEPREFIX/drive_c/Program Files/dotnet/" | head -5

# ============================================================================
# Install .NET Framework 4.8 (required for BC Reporting and some BC components)
# ============================================================================
RUN echo "=== Installing .NET Framework 4.8 (build-time initialization) ===" && \
    # Start temporary Xvfb for .NET 4.8 installation
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true && \
    export DISPLAY=":0" && \
    export XKB_DEFAULT_LAYOUT=us && \
    Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX & \
    XVFB_PID=$! && \
    sleep 3 && \
    \
    # Install .NET Framework 4.8 using winetricks
    echo "Installing .NET Framework 4.8 (this may take 5-10 minutes)..." && \
    WINEDLLPATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib/wine/x86_64-windows" \
    LD_LIBRARY_PATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib:${LD_LIBRARY_PATH}" \
    winetricks prefix=bc1 -q dotnet48 && \
    \
    # Cleanup
    wineserver --kill && \
    kill $XVFB_PID 2>/dev/null || true && \
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 && \
    \
    # Verify installation
    test -d "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319" && echo "✓ .NET Framework 4.8 installed successfully" || exit 1

# Mark that Wine and .NET are initialized in the image
RUN touch /home/.wine-initialized

# Create directories for BC usage
RUN mkdir -p /home/bcartifacts /home/bcserver/Keys /home/scripts /home/tests /root/.local/share/wineprefixes/bc1

# Show Wine version
RUN echo "Wine version installed:" && wine --version

# Create a simple test endpoint
COPY test-wine.sh /usr/local/bin/test-wine.sh
RUN chmod +x /usr/local/bin/test-wine.sh

# Default command - Wine and .NET are already initialized, just start shell
CMD ["/bin/bash"]