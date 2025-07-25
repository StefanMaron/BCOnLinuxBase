# BC Wine Base Image Usage Examples

This directory contains examples showing how to use the BC Wine Base image for building complete Business Central containers.

## Examples

### 1. `bc-simple/` - Minimal Approach
The most straightforward way to create a BC container with just the essentials.

**What it includes:**
- BC artifact download
- Basic configuration
- Simple entrypoint

**Best for:** Quick prototypes, testing, minimal deployments

### 2. `bc-full/` - Complete Approach  
Shows a more comprehensive BC container setup with additional Windows components and configurations.

**What it includes:**
- BC artifact download
- Additional Windows runtimes (vcrun2019, dotnet48)
- Comprehensive health checks
- Advanced configuration options

**Best for:** Production deployments, complex BC setups

### Key Difference from Legacy Approach

**Both examples now benefit from the enhanced base image:**
- ✅ All dependencies pre-installed (Wine, PowerShell, BC Container Helper)
- ✅ Pre-configured Wine environment
- ✅ Much smaller and faster builds
- ✅ Consistent foundation across all BC containers

**Legacy approach (before enhancement):**
- ❌ 50+ lines of dependency installation in each Dockerfile
- ❌ Repeated PowerShell and BC Container Helper setup
- ❌ Longer build times and larger images

## Size Comparison

| Approach | Dockerfile Lines | Build Time | Final Image Size |
|----------|------------------|------------|------------------|
| bc-simple (minimal) | ~40 lines | ~15 min | ~3.2GB |
| bc-full (comprehensive) | ~50 lines | ~20 min | ~3.5GB |
| Legacy (before base enhancement) | ~150 lines | ~45 min | ~4.2GB |

## Usage

### Quick Start with Simple Approach

```bash
# Build the enhanced base image first
cd ../
docker build -t bc-wine-base .

# Build BC container using simple approach
cd examples/bc-simple/
docker build -t my-bc-container .

# Run BC container
docker run -p 7046:7046 my-bc-container
```

### Customizing BC Version

```bash
# Build with specific BC version
docker build \
  --build-arg BC_VERSION=25 \
  --build-arg BC_COUNTRY=us \
  --build-arg BC_TYPE=OnPrem \
  -t my-bc-v25 \
  examples/bc-simple/
```

## Architecture

```
bc-wine-base (this repo)
├── Wine build with BC optimizations
├── All runtime dependencies
├── PowerShell + BC Container Helper
├── Pre-configured Wine prefix
└── BC-ready environment

    ↓ (inherit from)

your-bc-container
├── BC artifacts download
├── Custom configuration
├── Application-specific scripts
└── Runtime entrypoint
```

## Best Practices

1. **Use the enhanced base image** (`bc-wine-base`) that includes all dependencies
2. **Pin BC version** using build args for reproducible builds
3. **Keep customizations minimal** in derived images
4. **Use multi-stage builds** if you need build-time tools
5. **Leverage Docker layer caching** by putting stable operations first

## Environment Variables

The base image sets up these environment variables:

```bash
# Wine Configuration
WINEARCH=win64
WINEPREFIX=/opt/wine-prefix
PATH=/opt/wine-custom/bin:$PATH
LD_LIBRARY_PATH=/opt/wine-custom/lib64:/opt/wine-custom/lib

# Display Configuration
DISPLAY=:0
DEBIAN_FRONTEND=noninteractive

# BC Ports (can be overridden)
BCPORT=7046
BCMANAGEMENTPORT=7045
BCSOAPPORT=7047
BCODATAPORT=7048
BCDEVPORT=7049
```

## Troubleshooting

### Wine Issues
- Base image includes comprehensive Wine setup
- Wine prefix is pre-initialized at `/opt/wine-prefix`
- All necessary runtime libraries are included

### BC Container Helper Issues
- BC Container Helper is pre-installed in base image
- PowerShell is available and configured
- Use `pwsh` command for PowerShell operations

### Build Performance
- Use `--build-arg` to customize BC versions without rebuilding base
- Leverage Docker BuildKit for better caching
- Consider using remote cache for CI/CD pipelines
