# Wine builder stage for Business Central on Linux
FROM ubuntu:22.04 AS wine-builder

# Install Wine build dependencies
RUN apt-get update && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Build essentials
        build-essential \
        gcc-multilib \
        g++-multilib \
        flex \
        bison \
        # Source control
        git \
        wget \
        ca-certificates \
        # Wine build requirements
        autoconf \
        automake \
        libtool \
        pkg-config \
        make \
        perl \
        # Required perl modules for make_unicode
        libxml-libxml-perl \
        libdigest-sha-perl \
        # MinGW for Windows compatibility
        mingw-w64 \
        # Build acceleration
        ccache \
        # Python for Wine Staging
        python3 \
        python3-pip \
        # X11 development libraries
        libx11-dev \
        libx11-dev:i386 \
        libfreetype6-dev \
        libfreetype6-dev:i386 \
        libxcursor-dev \
        libxcursor-dev:i386 \
        libxi-dev \
        libxi-dev:i386 \
        libxext-dev \
        libxext-dev:i386 \
        libxrandr-dev \
        libxrandr-dev:i386 \
        libxrender-dev \
        libxrender-dev:i386 \
        libxinerama-dev \
        libxinerama-dev:i386 \
        libgl1-mesa-dev \
        libgl1-mesa-dev:i386 \
        libglu1-mesa-dev \
        libglu1-mesa-dev:i386 \
        # Additional libraries for better compatibility
        libasound2-dev \
        libasound2-dev:i386 \
        libpulse-dev \
        libpulse-dev:i386 \
        libdbus-1-dev \
        libdbus-1-dev:i386 \
        libfontconfig1-dev \
        libfontconfig1-dev:i386 \
        libgnutls28-dev \
        libgnutls28-dev:i386 \
        libncurses-dev \
        libncurses-dev:i386 \
        libldap2-dev \
        libldap2-dev:i386 \
        libcups2-dev \
        libcups2-dev:i386 \
        # Development tools
        gettext \
        libxml2-dev \
        libxslt1-dev \
        libssl-dev \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Set up ccache
ENV PATH="/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR=/ccache
RUN mkdir -p /ccache && \
    ccache --max-size=2G

# Clone latest Wine source
RUN git clone --depth 1 https://gitlab.winehq.org/wine/wine.git /wine-src

# Clone and apply Wine Staging patches
RUN git clone --depth 1 https://github.com/wine-staging/wine-staging.git /wine-staging && \
    cd /wine-staging && \
    python3 ./staging/patchinstall.py DESTDIR=/wine-src --all

# Copy and apply the locale display fix patch
COPY wine-locale-display-fix.patch /wine-locale-display-fix.patch
RUN cd /wine-src && \
    patch -p1 < /wine-locale-display-fix.patch || { \
        echo "Patch failed, attempting to apply manually..."; \
        # If patch fails, try to apply the changes manually
        cp /wine-locale-display-fix.patch /tmp/; \
    }

# Regenerate locale data with the fix
RUN cd /wine-src/tools && \
    perl make_unicode && \
    cd ..

# Create build directories
RUN mkdir -p /wine-build/wine64 /wine-build/wine32

# Configure and build 64-bit Wine
RUN cd /wine-build/wine64 && \
    CC="ccache gcc" CROSSCC="ccache x86_64-w64-mingw32-gcc" \
    /wine-src/configure \
        --enable-win64 \
        --prefix=/opt/wine-custom \
        --disable-tests \
    && make -j$(nproc)

# Configure and build 32-bit Wine with 64-bit support
RUN cd /wine-build/wine32 && \
    CC="ccache gcc -m32" CROSSCC="ccache i686-w64-mingw32-gcc" \
    PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig \
    /wine-src/configure \
        --with-wine64=/wine-build/wine64 \
        --prefix=/opt/wine-custom \
        --disable-tests \
    && make -j$(nproc)

# Install Wine (64-bit first, then 32-bit)
RUN cd /wine-build/wine64 && make install && \
    cd /wine-build/wine32 && make install

# Create version file
RUN /opt/wine-custom/bin/wine --version > /opt/wine-custom/wine-version.txt

# Final minimal image with Wine build artifacts
FROM ubuntu:22.04

# Copy custom Wine build from builder stage
COPY --from=wine-builder /opt/wine-custom /opt/wine-custom
COPY --from=wine-builder /opt/wine-custom/wine-version.txt /opt/wine-custom/wine-version.txt

# Install minimal runtime dependencies for Wine and BC
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Essential Wine runtime dependencies
        libc6:i386 \
        libx11-6:i386 \
        libx11-6 \
        libfreetype6:i386 \
        libfreetype6 \
        # Additional Wine runtime libraries needed for BC
        libxcomposite1:i386 \
        libxcomposite1 \
        libxss1:i386 \
        libxss1 \
        libgconf-2-4:i386 \
        libgconf-2-4 \
        libnss3:i386 \
        libnss3 \
        libxrandr2:i386 \
        libxrandr2 \
        libasound2:i386 \
        libasound2 \
        libpangocairo-1.0-0:i386 \
        libpangocairo-1.0-0 \
        libatk1.0-0:i386 \
        libatk1.0-0 \
        libcairo-gobject2:i386 \
        libcairo-gobject2 \
        libgtk-3-0:i386 \
        libgtk-3-0 \
        libgdk-pixbuf2.0-0:i386 \
        libgdk-pixbuf2.0-0 \
        libpulse0:i386 \
        libpulse0 \
        libdbus-1-3:i386 \
        libdbus-1-3 \
        libgnutls30:i386 \
        libgnutls30 \
        libncurses6:i386 \
        libncurses6 \
        libldap-2.5-0:i386 \
        libldap-2.5-0 \
        libcups2:i386 \
        libcups2 \
        libfontconfig1:i386 \
        libfontconfig1 \
        libxcursor1:i386 \
        libxcursor1 \
        libxi6:i386 \
        libxi6 \
        libxext6:i386 \
        libxext6 \
        libxrender1:i386 \
        libxrender1 \
        libxinerama1:i386 \
        libxinerama1 \
        libgl1:i386 \
        libgl1 \
        libglu1-mesa:i386 \
        libglu1-mesa \
        # Required tools for BC
        winbind \
        p7zip-full \
        net-tools \
        cabextract \
        wget \
        curl \
        gnupg2 \
        software-properties-common \
        xvfb \
        xauth \
        unzip \
        locales \
        lsb-release \
        apt-transport-https \
        ca-certificates \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install winetricks for additional Windows components
RUN wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks

# Install PowerShell for BC Container Helper
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    rm -rf /var/lib/apt/lists/*

# Set Wine environment
ENV PATH="/opt/wine-custom/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/wine-custom/lib64:/opt/wine-custom/lib:${LD_LIBRARY_PATH}" \
    WINEARCH=win64 \
    WINEPREFIX=/opt/wine-prefix \
    DEBIAN_FRONTEND=noninteractive \
    DISPLAY=":0"

# Set shell to PowerShell for BC Container Helper installation
SHELL ["pwsh", "-Command"]

# Install BC Container Helper
RUN Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name BcContainerHelper -Force -AllowClobber -Scope AllUsers

# Switch back to bash
SHELL ["/bin/bash", "-c"]

# Create directories for BC usage
RUN mkdir -p /home/bcartifacts /home/bcserver/Keys /home/scripts /opt/wine-prefix

# Initialize Wine prefix with BC-optimized settings
RUN export WINEPREFIX=/opt/wine-prefix && \
    export WINEARCH=win64 && \
    wineboot --init && \
    # Set Wine to Windows 10 mode for better BC compatibility
    wine reg add "HKEY_CURRENT_USER\Software\Wine\Version" /v "Windows" /t REG_SZ /d "10" /f && \
    # Configure Direct3D for better performance
    wine reg add "HKEY_CURRENT_USER\Software\Wine\Direct3D" /v "renderer" /t REG_SZ /d "gl" /f && \
    wine reg add "HKEY_CURRENT_USER\Software\Wine\Direct3D" /v "DirectDrawRenderer" /t REG_SZ /d "opengl" /f && \
    # Wait for wineserver to finish
    wineserver --wait

# Show Wine version
RUN echo "Wine version installed:" && cat /opt/wine-custom/wine-version.txt

# Create a simple test endpoint
COPY test-wine.sh /usr/local/bin/test-wine.sh
RUN chmod +x /usr/local/bin/test-wine.sh

# Default command
CMD ["/usr/local/bin/test-wine.sh"]
