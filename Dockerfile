# Start with Ubuntu 24.04 base image
FROM ubuntu:24.04

# Download Wine, install all dependencies, and Microsoft tools in single layer
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Download tools
        wget \
        curl \
        ca-certificates \
        gnupg2 \
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
        libasound2t64:i386 \
        libasound2t64 \
        libpulse0:i386 \
        libpulse0 \
        libdbus-1-3:i386 \
        libdbus-1-3 \
        libgnutls30t64:i386 \
        libgnutls30t64 \
        libncurses6:i386 \
        libncurses6 \
        libldap-common \
        libcups2:i386 \
        libcups2 \
        # Required tools
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
    && wget -q "https://github.com/SShadowS/wine64-bc4ubuntu/releases/latest/download/wine.tar.gz" -O /tmp/wine.tar.gz \
    && cd / && tar -xzf /tmp/wine.tar.gz && cd - \
    && rm /tmp/wine.tar.gz \
    && wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks \
    && chmod +x /usr/bin/winetricks \
    && wget -q "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev \
    && echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bash.bashrc \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure dynamic linker for Wine libraries - must be after Wine extraction
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wine.conf && \
    echo "/usr/local/lib/wine" >> /etc/ld.so.conf.d/wine.conf && \
    echo "/usr/local/lib/wine/x86_64-unix" >> /etc/ld.so.conf.d/wine.conf && \
    ldconfig -v 2>&1 | grep -E "^/usr/local" || true && \
    ldconfig

# Set Wine environment
ENV PATH="/usr/local/bin:${PATH}" \
    LD_LIBRARY_PATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib" \
    WINEDLLPATH="/usr/local/lib/wine/x86_64-unix:/usr/local/lib/wine/x86_64-windows" \
    WINEARCH=win64 \
    WINEPREFIX=/root/.local/share/wineprefixes/bc1 \
    DEBIAN_FRONTEND=noninteractive \
    DISPLAY=":0" \
    WINE_SKIP_GECKO_INSTALLATION=1 \
    WINE_SKIP_MONO_INSTALLATION=1 \
    WINEDEBUG=-winediag

# Install BC Container Helper during build for artifact download
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name BcContainerHelper -Force -AllowClobber -Scope AllUsers"

# Create directories for BC usage
RUN mkdir -p /home/bcartifacts /home/bcserver/Keys /home/scripts /home/tests /root/.local/share/wineprefixes/bc1

# Copy Wine culture fix script
COPY fix-wine-cultures.sh /usr/local/bin/fix-wine-cultures.sh
RUN chmod +x /usr/local/bin/fix-wine-cultures.sh

# Create wine initialization scripts for runtime
COPY wine-init-runtime.sh /usr/local/bin/wine-init-runtime.sh
COPY wine-init-full.sh /usr/local/bin/wine-init-full.sh
RUN chmod +x /usr/local/bin/wine-init-runtime.sh /usr/local/bin/wine-init-full.sh

# Show Wine version
RUN echo "Wine version installed:" && wine --version

# Create a simple test endpoint
COPY test-wine.sh /usr/local/bin/test-wine.sh
RUN chmod +x /usr/local/bin/test-wine.sh

# Default command - initialize Wine at runtime
CMD ["/usr/local/bin/wine-init-runtime.sh"]