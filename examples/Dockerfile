# Simplified BC Image using enhanced bc-wine-base
# This demonstrates how much simpler it is with all BC dependencies in the base image

FROM your-username/bc-wine-base:latest

# Set BC-specific environment variables
ENV BCPORT=7046 \
    BCMANAGEMENTPORT=7045 \
    BCSOAPPORT=7047 \
    BCODATAPORT=7048 \
    BCDEVPORT=7049 \
    WINEPREFIX=/opt/wine-prefix

# Download BC artifacts (configurable version)
ARG BC_VERSION=26
ARG BC_COUNTRY=w1
ARG BC_TYPE=Sandbox

# Set shell to PowerShell for BC artifacts download
SHELL ["pwsh", "-Command"]

# Download and install BC artifacts
RUN $artifactUrl = Get-BCartifactUrl -version ${BC_VERSION} -country ${BC_COUNTRY} -type ${BC_TYPE}; \
    Write-Host "Downloading BC artifacts from: $artifactUrl"; \
    $artifactPaths = Download-Artifacts $artifactUrl -includePlatform; \
    Write-Host "Artifact paths received:"; \
    $artifactPaths | ForEach-Object { Write-Host "  $_" }; \
    Write-Host "Copying platform artifacts first from: $($artifactPaths[1])"; \
    Copy-Item -Path "$($artifactPaths[1])/*" -Destination "/home/bcartifacts" -Recurse -Force; \
    Write-Host "Copying application artifacts second from: $($artifactPaths[0])"; \
    Copy-Item -Path "$($artifactPaths[0])/*" -Destination "/home/bcartifacts" -Recurse -Force; \
    Write-Host "BC artifact structure:"; \
    Get-ChildItem "/home/bcartifacts" -Recurse -Depth 1 | Select-Object FullName | ForEach-Object { Write-Host "  $($_.FullName)" }

# Switch back to bash
SHELL ["/bin/bash", "-c"]

# Copy BC configuration and scripts
COPY CustomSettings.config /home/
COPY entrypoint.sh /home/
RUN chmod +x /home/entrypoint.sh

# Install essential Windows components for BC
RUN export WINEPREFIX=/opt/wine-prefix && \
    # Install required Windows runtimes
    winetricks -q corefonts vcrun2019 dotnet48 && \
    # Wait for installation to complete
    wineserver --wait

# Expose BC ports
EXPOSE 7045 7046 7047 7048 7049 80 443

# Health check for BC services
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
    CMD curl -f http://localhost:${BCPORT}/BC/HealthCheck || exit 1

# Set entrypoint
ENTRYPOINT ["/home/entrypoint.sh"]
CMD ["start-bc"]
