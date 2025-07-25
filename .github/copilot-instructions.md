<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# BC Linux Wine Base Project Instructions

This is a Docker project that builds a custom Wine installation optimized for Business Central on Linux. The project includes:

## Key Components
- **Custom Wine Build**: Compiles Wine from source with Business Central optimizations
- **Wine Staging Patches**: Includes compatibility improvements
- **Multi-platform Support**: Builds for linux/amd64 and linux/arm64
- **GitHub Actions**: Automated CI/CD pipeline for building and publishing Docker images
- **Docker Hub Publishing**: Images are published to Docker Hub public registry
- **Security**: Images are signed using cosign for supply chain security

## Development Guidelines
- Use Ubuntu 22.04 LTS as the base image
- Optimize Wine build for Business Central compatibility
- Include locale display fix patches
- Use ccache for faster compilation
- Follow multi-stage build patterns for smaller final images
- Maintain both 32-bit and 64-bit Wine support

## Wine Build Process
- Clone latest Wine source from GitLab
- Apply Wine Staging patches for improved compatibility
- Apply custom patches for Business Central
- Build both 64-bit and 32-bit Wine versions
- Install to /opt/wine-custom for isolation

## CI/CD Pipeline
- Extended timeout (180 minutes) for Wine compilation
- Builds trigger on pushes to main/master branches
- Docker images are tagged with git SHA, branch names, semantic versions, and date stamps
- Only pushes to main branch and tags publish to Docker Hub
- Pull requests only build images for testing
- Manual workflow dispatch available for testing

## Environment Variables
- `WINEARCH`: Wine architecture (win64)
- `WINEPREFIX`: Wine prefix location
- `PATH`: Includes /opt/wine-custom/bin
- `LD_LIBRARY_PATH`: Includes Wine library paths

## Security Considerations
- Multi-stage builds to reduce final image size
- Minimal runtime dependencies in final image
- Sign published images with cosign
- Regular base image updates
- Secure Wine configuration

## Testing
- Include test script to validate Wine installation
- Test basic Wine registry functionality
- Verify Wine version and library availability
- Support interactive testing mode
