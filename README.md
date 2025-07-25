# BC Linux Wine Base

A Docker base image with custom Wine build optimized for running Business Central on Linux environments.

## 🍷 Overview

This project builds a comprehensive Wine base image optimized for Microsoft Dynamics 365 Business Central on Linux. It includes Wine Staging patches, Business Central compatibility fixes, PowerShell, BC Container Helper, and all necessary runtime dependencies in a single, ready-to-use base image.

## 🚀 Features

- **Complete BC Environment**: Wine, PowerShell, BC Container Helper, and all dependencies pre-installed
- **Custom Wine Build**: Latest Wine compiled from source with BC-specific optimizations
- **Wine Staging**: Enhanced compatibility through Wine Staging patches
- **Locale Fixes**: Advanced patches for Business Central locale display issues
- **Multi-platform**: Supports linux/amd64 and linux/arm64 architectures
- **Automated Builds**: GitHub Actions CI/CD with extended build timeouts
- **Signed Images**: All published images are signed with cosign for security
- **Pre-configured Wine**: Wine prefix initialized with BC-optimized settings
- **Minimal Derived Images**: Drastically simplified BC container creation

## 📋 Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed
- GitHub account for CI/CD setup
- Docker Hub account for image publishing
- Significant build time (60-120 minutes for full Wine compilation)

## 🛠️ Quick Start

### Using Pre-built Image

```bash
# Pull the latest base image
docker pull your-username/bc-wine-base:latest

# Test Wine and BC environment
docker run --rm your-username/bc-wine-base:latest

# Interactive shell to explore
docker run --rm -it your-username/bc-wine-base:latest /bin/bash

# Check PowerShell and BC Container Helper
docker run --rm your-username/bc-wine-base:latest pwsh -c "Get-Module -ListAvailable BcContainerHelper"
```

### Building a BC Container

Create a simple Dockerfile using the base image:

```dockerfile
FROM your-username/bc-wine-base:latest

# Set BC version (optional build args)
ARG BC_VERSION=26
ARG BC_COUNTRY=w1
ARG BC_TYPE=Sandbox

# Download BC artifacts
SHELL ["pwsh", "-Command"]
RUN $artifactUrl = Get-BCartifactUrl -version ${BC_VERSION} -country ${BC_COUNTRY} -type ${BC_TYPE}; \
    $artifactPaths = Download-Artifacts $artifactUrl -includePlatform; \
    Copy-Item -Path "$($artifactPaths[1])/*" -Destination "/home/bcartifacts" -Recurse -Force; \
    Copy-Item -Path "$($artifactPaths[0])/*" -Destination "/home/bcartifacts" -Recurse -Force

# Add your BC configuration
COPY CustomSettings.config /home/
COPY entrypoint.sh /home/
RUN chmod +x /home/entrypoint.sh

EXPOSE 7046
ENTRYPOINT ["/home/entrypoint.sh"]
```

Build and run:

```bash
docker build -t my-bc-container .
docker run -p 7046:7046 my-bc-container
```

### Building Locally

```bash
# Clone the repository
git clone <your-repo-url>
cd BCOnLinuxBase

# Build the image (this will take 60-120 minutes)
docker build -t bc-wine-base .

# Test the build
docker run --rm bc-wine-base
```

## 🔧 Configuration

### Wine Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WINEARCH` | Wine architecture | `win64` |
| `WINEPREFIX` | Wine prefix location | `/opt/wine-prefix` |
| `PATH` | System PATH with Wine | `/opt/wine-custom/bin:$PATH` |
| `LD_LIBRARY_PATH` | Wine library paths | `/opt/wine-custom/lib64:/opt/wine-custom/lib` |
| `DISPLAY` | X11 display for headless operation | `:0` |
| `BCPORT` | Business Central web client port | `7046` |
| `BCMANAGEMENTPORT` | BC management service port | `7045` |

### Docker Hub Setup

1. **Create Docker Hub repository**
   - Go to [Docker Hub](https://hub.docker.com/)
   - Create a new repository (e.g., `username/bc-wine-base`)

2. **Configure GitHub Secrets**
   Go to your GitHub repository → Settings → Secrets and variables → Actions, and add:
   
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token

3. **Update workflow configuration**
   Edit `.github/workflows/docker-publish.yml` and update the `IMAGE_NAME` environment variable.

## 🏗️ Build Process

### Wine Compilation Stages

1. **Dependency Installation**: Installs build tools, libraries, and Wine dependencies
2. **Source Preparation**: Clones Wine source and Wine Staging patches
3. **Patch Application**: Applies Business Central compatibility patches
4. **Unicode Generation**: Regenerates locale data with fixes
5. **Compilation**: Builds both 64-bit and 32-bit Wine versions
6. **Installation**: Installs Wine to `/opt/wine-custom`
7. **Runtime Image**: Creates minimal final image with Wine and essential libraries

### Build Optimization

- **ccache**: Accelerates recompilation during development
- **Multi-stage**: Separates build environment from runtime
- **Parallel builds**: Uses all available CPU cores
- **Layer caching**: GitHub Actions cache for faster CI builds

## 🚢 Deployment

### Automatic Deployment

Images are automatically built and published when:

- **Push to main/master**: Creates `latest` and dated tags
- **Release tags** (v1.0.0): Creates semantic version tags
- **Manual trigger**: Workflow dispatch for testing builds

### Build Times

- **First build**: 90-120 minutes (full Wine compilation)
- **Cached builds**: 30-60 minutes (with layer caching)
- **CI builds**: Extended timeout of 180 minutes

## 🏗️ Architecture

```
BCOnLinuxBase/
├── .github/
│   ├── workflows/
│   │   └── docker-publish.yml      # Extended CI/CD for Wine builds
│   └── copilot-instructions.md     # Wine-specific AI instructions
├── Dockerfile                      # Multi-stage Wine build
├── wine-locale-display-fix.patch   # BC locale compatibility patch
├── test-wine.sh                    # Wine functionality test script
├── package.json                    # Build metadata and scripts
├── .dockerignore                   # Build context optimization
└── README.md                       # This file
```

## 🔒 Security Features

- **Multi-stage builds**: Minimal attack surface in final image
- **Image signing**: All published images signed with cosign
- **Minimal runtime**: Only essential libraries in final image
- **Regular updates**: Automated base image updates
- **Source builds**: Compiled from verified Wine sources

## 🧪 Testing Wine Installation

The image includes a test script that validates:

- Wine version and installation paths
- Basic Wine registry functionality
- Library availability
- Wine prefix initialization

```bash
# Run basic tests
docker run --rm bc-wine-base

# Keep container alive for manual testing
docker run --rm bc-wine-base --keep-alive

# Interactive Wine testing
docker run --rm -it bc-wine-base /bin/bash
# Inside container:
wine --version
winecfg  # (requires X11 forwarding for GUI)
```

## 📦 Usage in Business Central Projects

This image serves as a base for Business Central on Linux containers:

```dockerfile
FROM your-username/bc-wine-base:latest

# Add BC-specific components
COPY bcartifacts/ /home/bcartifacts/
COPY scripts/ /home/

# Install additional BC dependencies
RUN apt-get update && apt-get install -y \
    powershell \
    && rm -rf /var/lib/apt/lists/*

# Configure BC environment
ENV BCPORT=7046
EXPOSE 7046 7047 7048 7049

ENTRYPOINT ["/home/start-bc.sh"]
```

## 🛠️ Development

### Modifying Wine Build

1. **Update patches**: Modify `wine-locale-display-fix.patch`
2. **Build configuration**: Adjust Wine configure options in Dockerfile
3. **Test locally**: Build and test with development scripts
4. **CI testing**: Push to feature branch for automated testing

### Adding Dependencies

1. **Build stage**: Add to wine-builder stage for compilation
2. **Runtime stage**: Add only essential runtime libraries
3. **Size optimization**: Use `--no-install-recommends`

### Troubleshooting

**Build failures:**
- Check Wine source availability
- Verify patch compatibility with Wine version
- Monitor build timeout limits

**Runtime issues:**
- Test Wine installation with included test script
- Check library dependencies with `ldd`
- Verify Wine prefix permissions

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/wine-improvement`)
3. Test Wine build locally
4. Commit your changes (`git commit -m 'Improve Wine compatibility'`)
5. Push to the branch (`git push origin feature/wine-improvement`)
6. Open a Pull Request

## 📞 Support

- Create an [issue](../../issues) for Wine build problems or BC compatibility issues
- Check [Wine AppDB](https://appdb.winehq.org/) for application compatibility
- Review [Business Central on Linux documentation](https://docs.microsoft.com/dynamics365/business-central/)

---

**🍷 Built with Wine for Business Central on Linux**
