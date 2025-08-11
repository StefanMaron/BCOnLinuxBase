FROM ubuntu:22.04 AS wine-builder

# Install Wine build dependencies
RUN dpkg --add-architecture i386 && \
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

# Copy patch application script and patches directory
COPY apply-wine-patches.sh /apply-wine-patches.sh
COPY wine-patches /wine-patches
RUN chmod +x /apply-wine-patches.sh

# Apply all custom Wine patches from the patches directory
RUN /apply-wine-patches.sh /wine-src /wine-patches

# Regenerate locale data after patches
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

# Final minimal image with Wine build artifacts (NO Wine initialization here)
FROM ubuntu:22.04

# Copy custom Wine build from builder stage
COPY --from=wine-builder /opt/wine-custom /opt/wine-custom
COPY --from=wine-builder /opt/wine-custom/wine-version.txt /opt/wine-custom/wine-version.txt
COPY --from=wine-builder /wine-src/PATCHES_APPLIED.txt /opt/wine-custom/PATCHES_APPLIED.txt

# Install runtime dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Wine runtime dependencies
        libc6:i386 \
        libx11-6:i386 \
        libx11-6 \
        libfreetype6:i386 \
        libfreetype6 \
        libfontconfig1:i386 \
        libfontconfig1 \
        libxcursor1:i386 \
        libxcursor1 \
        libxi6:i386 \
        libxi6 \
        libxext6:i386 \
        libxext6 \
        libxrandr2:i386 \
        libxrandr2 \
        libxrender1:i386 \
        libxrender1 \
        libxinerama1:i386 \
        libxinerama1 \
        libgl1:i386 \
        libgl1 \
        libglu1-mesa:i386 \
        libglu1-mesa \
        libasound2:i386 \
        libasound2 \
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
        # Required tools
        winbind \
        p7zip-full \
        net-tools \
        cabextract \
        wget \
        curl \
        gnupg2 \
        software-properties-common \
        ca-certificates \
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
        net-tools \
        iputils-ping \
        dnsutils \
        telnet \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install winetricks
RUN wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks

# Install Microsoft repository and packages (PowerShell and SQL tools)
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bash.bashrc && \
    rm -rf /var/lib/apt/lists/*

# Set Wine environment
ENV PATH="/opt/wine-custom/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/wine-custom/lib64:/opt/wine-custom/lib:${LD_LIBRARY_PATH}" \
    WINEARCH=win64 \
    WINEPREFIX=/opt/wine-prefix \
    DEBIAN_FRONTEND=noninteractive \
    DISPLAY=":0" \
    WINE_SKIP_GECKO_INSTALLATION=1 \
    WINE_SKIP_MONO_INSTALLATION=1 \
    WINEDEBUG=-winediag

# Note: BC Container Helper installation moved to runtime script

# Create directories for BC usage
RUN mkdir -p /home/bcartifacts /home/bcserver/Keys /home/scripts /opt/wine-prefix

# Copy Wine culture fix script
COPY fix-wine-cultures.sh /usr/local/bin/fix-wine-cultures.sh
RUN chmod +x /usr/local/bin/fix-wine-cultures.sh

# Create wine initialization script for runtime
COPY wine-init-runtime.sh /usr/local/bin/wine-init-runtime.sh
RUN chmod +x /usr/local/bin/wine-init-runtime.sh

# Show Wine version
RUN echo "Wine version installed:" && cat /opt/wine-custom/wine-version.txt

# Create a simple test endpoint
COPY test-wine.sh /usr/local/bin/test-wine.sh
RUN chmod +x /usr/local/bin/test-wine.sh

# Default command - initialize Wine at runtime
CMD ["/usr/local/bin/wine-init-runtime.sh"]