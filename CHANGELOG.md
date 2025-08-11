# Changelog

## [2024-08-11] - Major Update from BCDevOnLinux Repository

### 🚀 Added
- **Enhanced Wine Patches**: Updated from consolidated patches to individual patches for better maintainability
  - `nls_locale.nls.patch` - Locale system fixes
  - `tools_make_unicode.patch` - Unicode generation improvements  
  - `dlls_httpapi_httpapi_main.c.patch` - HTTP API function implementations
  - `dlls_httpapi_httpapi.spec.patch` - HTTP API specifications
  - `dlls_http.sys_http.c.patch` - HTTP.SYS compatibility improvements
  - `include_wine_http.h.patch` - HTTP API header definitions

- **.NET Framework 4.8 Pre-installation**: Major time-saving improvement
  - .NET Framework 4.8 now installed during base image build
  - Reduces BC container startup time from ~15-20 minutes to ~3-5 minutes
  - Version-independent stable foundation for all BC versions

- **Enhanced Wine Configuration**:
  - Wine prefix set to Windows 11 mode for better BC compatibility
  - Advanced registry settings for BC Server optimization
  - Pre-configured graphics settings for headless operation
  - Strong cryptography enabled for .NET Framework
  - Wine culture fixes applied to prevent locale enumeration issues
  - Gecko and Mono installation disabled for cleaner environment
  - Wine debug output minimized for better performance

### 🔧 Changed  
- **Wine Patches Structure**: Migrated from consolidated to modular patch system
- **Build Time**: Increased to 90-150 minutes due to .NET Framework installation
- **Wine Configuration**: Updated to match latest BCDevOnLinux optimizations
- **Documentation**: Updated README with detailed pre-installation information

### 📦 Migration Benefits
- **Faster BC Deployments**: Pre-installed .NET Framework 4.8 eliminates longest startup delay
- **Better Compatibility**: Latest Wine patches ensure HTTP API and locale functionality
- **Simplified Derived Images**: BC containers now only need version-specific .NET components
- **Consistent Foundation**: Standardized Wine environment across all BC versions

### 🛠️ Technical Details
- Wine patches applied in modular fashion for easier maintenance
- Virtual display management during .NET installation
- Comprehensive registry configuration for BC compatibility
- Optimized layer caching for CI/CD builds

### 📋 What's Pre-installed
- Wine 9.x with Business Central compatibility patches
- Wine Staging patches for enhanced Windows compatibility
- .NET Framework 4.8 (stable, version-independent)
- PowerShell and BC Container Helper
- SQL Server tools (sqlcmd, etc.)
- Pre-initialized Wine prefix with BC-optimized settings

### 🔄 Migration Guide for Derived Images
BC container Dockerfiles can now be simplified:

**Before:**
- Long Wine initialization during container startup
- Full .NET Framework installation on every container start
- 15-20 minute startup time

**After:**
- Pre-configured Wine environment ready to use
- Only install version-specific .NET components (e.g., .NET 8)
- 3-5 minute startup time

### ⚠️ Important Notes
- Version-specific .NET components (.NET 8, etc.) should still be installed in derived images
- This maintains compatibility with different BC versions requiring different .NET versions
- The base image provides the stable foundation (.NET Framework 4.8) needed by all BC versions