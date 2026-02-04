# cortex-cli-nix

Always up-to-date Nix package for [Snowflake Cortex Code CLI](https://ai.snowflake.com/) - AI coding assistant in your terminal.

**🚀 Automatically updated hourly** to ensure you always have the latest Cortex CLI version.

## What is Cortex Code CLI?

Cortex Code CLI (also known as `coco`) is Snowflake's AI-powered coding assistant that runs in your terminal. It provides intelligent code suggestions, helps with debugging, and assists with various development tasks using Snowflake's AI capabilities.

## Quick Start

### Fastest Installation (Try it now!)

```bash
# Run Cortex CLI directly without installing
nix run github:xorq-labs/cortex-cli-nix
```

### Install to Your System

```bash
# Install to your profile (survives reboots)
nix profile install github:xorq-labs/cortex-cli-nix
```

## Features

- **Always Up-to-Date**: Automated hourly checks and updates via GitHub Actions
- **Pre-built Binaries**: Cachix provides instant installation without compilation
- **Flake-native**: Modern Nix flake for composable, reproducible deployments
- **Node.js 22 LTS Bundled**: No need to install Node.js separately
- **Multi-platform**: Supports macOS (ARM64/Intel) and Linux (x86_64/ARM64)

## Installation Options

### Standalone Installation (Without Home Manager)

If you're not using Home Manager or NixOS, here's the complete workflow for managing Cortex CLI with `nix profile`.

#### Install

```bash
# Install cortex-cli
nix profile install github:xorq-labs/cortex-cli-nix

# Verify installation
which cortex
cortex --version
```

#### Update to Latest Version

```bash
# Update all flake-based packages
nix profile upgrade --all

# Or update only cortex-cli
nix profile upgrade '.*cortex-cli.*'
```

#### Rollback

```bash
# Revert to previous profile state
nix profile rollback
```

#### Uninstall

```bash
nix profile remove '.*cortex-cli.*'
```

### Using with NixOS

Add to your `configuration.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    cortex-cli.url = "github:xorq-labs/cortex-cli-nix";
  };

  outputs = { self, nixpkgs, cortex-cli, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.overlays = [ cortex-cli.overlays.default ];
          environment.systemPackages = [ pkgs.cortex-cli ];
        }
      ];
    };
  };
}
```

### Using with Home Manager

Add to your Home Manager configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    cortex-cli.url = "github:xorq-labs/cortex-cli-nix";
  };

  outputs = { self, nixpkgs, home-manager, cortex-cli, ... }: {
    homeConfigurations."username" = home-manager.lib.homeManagerConfiguration {
      modules = [
        {
          nixpkgs.overlays = [ cortex-cli.overlays.default ];
          home.packages = [ pkgs.cortex-cli ];
        }
      ];
    };
  };
}
```

### Optional: Enable Binary Cache for Faster Installation

To download pre-built binaries instead of compiling:

```bash
# Install cachix if you haven't already
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Configure the xorq-labs cache
cachix use xorq-labs
```

Or add to your Nix configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://xorq-labs.cachix.org" ];
    trusted-public-keys = [ "xorq-labs.cachix.org-1:yw5TptZAA4ry8WZ8VEAy4e4T8bdIhoeiLC5YlR5cOo4=" ];
  };
}
```

## Version Pinning

Pin to specific Cortex CLI versions using git refs. This allows you to control exactly which version you use.

### Available Tags

| Tag | Example | Behavior |
|-----|---------|----------|
| `vX.Y.Z+BUILD.HASH` | `v1.0.5+022417.2cafbd3cf8db` | Exact version (immutable) |
| `vX.Y.Z` | `v1.0.5` | Latest build for that version (updates automatically) |
| `vX` | `v1` | Latest in major series (updates automatically) |
| `latest` | `latest` | Always newest version (updates automatically) |

### Usage Examples

```bash
# Always latest (default)
nix run github:xorq-labs/cortex-cli-nix

# Pin to exact version with build
nix run github:xorq-labs/cortex-cli-nix?ref=v1.0.5+022417.2cafbd3cf8db

# Track latest build of v1.0.5 (auto-updates)
nix run github:xorq-labs/cortex-cli-nix?ref=v1.0.5

# Track latest v1.x (auto-updates within major version)
nix run github:xorq-labs/cortex-cli-nix?ref=v1

# Explicit latest
nix run github:xorq-labs/cortex-cli-nix?ref=latest
```

### In Flake Inputs

```nix
{
  inputs = {
    # Always latest
    cortex-cli.url = "github:xorq-labs/cortex-cli-nix";

    # Pin to exact version
    cortex-cli.url = "github:xorq-labs/cortex-cli-nix?ref=v1.0.5+022417.2cafbd3cf8db";

    # Track major.minor version
    cortex-cli.url = "github:xorq-labs/cortex-cli-nix?ref=v1.0.5";

    # Track major version
    cortex-cli.url = "github:xorq-labs/cortex-cli-nix?ref=v1";
  };
}
```

### Automatic Tag Creation

Tags are automatically created and updated after each successful build:
- **Exact version tags** (like `v1.0.5+022417.2cafbd3cf8db`) are created once and never change
- **Moving tags** (like `v1.0.5`, `v1`, `latest`) are updated to point to the newest matching version
- All tags are created within 1 hour of a new version being released

## Technical Details

### Package Architecture

The package:
- Downloads pre-built tarballs from Snowflake's S3 distribution
- Bundles Node.js 22 LTS (required runtime)
- Creates a wrapper script that handles Node.js execution
- Supports darwin-arm64, darwin-amd64, linux-amd64, linux-arm64

### Distribution Method

Unlike most npm packages, Cortex CLI is distributed via Snowflake's S3 bucket:
- **S3 Base URL**: `https://sfc-repo.snowflakecomputing.com/cortex-code-cli/a4643c4278/`
- **Version File**: `stable_version.txt`
- **Manifest**: `{version}/manifest.json` (contains checksums for all platforms)
- **Tarballs**: `{version}/coco-{version}-{platform}.tar.gz`

### Version Format

Cortex CLI uses a unique version format: `MAJOR.MINOR.PATCH+BUILD.HASH`

Example: `1.0.5+022417.2cafbd3cf8db`

The `+` character is URL-encoded to `%2B` when fetching from S3.

## Development

```bash
# Clone the repository
git clone https://github.com/xorq-labs/cortex-cli-nix
cd cortex-cli-nix

# Build the package
nix build

# Run tests
nix run . -- --version

# Check for version updates
./scripts/update-version.sh --check

# Enter development shell
nix develop
```

## Updating Cortex CLI Version

### Automated Updates

This repository uses GitHub Actions to automatically check for new Cortex CLI versions every hour. When a new version is detected:

1. A pull request is automatically created with the version update
2. Checksums are automatically fetched from the manifest
3. Tests run on both Ubuntu and macOS to verify the build
4. The PR auto-merges if all checks pass

The automated update workflow runs:
- Every hour (at the top of the hour)
- On manual trigger via GitHub Actions UI

This means new Cortex CLI versions are typically available in this flake within 30 minutes of being published!

### Manual Updates

#### Using the Update Script (Recommended)

```bash
# Check for updates
./scripts/update-version.sh --check

# Update to latest version
./scripts/update-version.sh

# Update to specific version
./scripts/update-version.sh --version 1.0.5+022417.2cafbd3cf8db

# Show help
./scripts/update-version.sh --help
```

The script automatically:
- Fetches the latest version from S3
- Downloads the manifest with checksums
- Updates `package.nix` with new version and all platform hashes
- Updates `flake.lock` with latest nixpkgs
- Verifies the build succeeds

## Troubleshooting

### PATH issues

If `cortex` command is not found after installation, ensure `~/.nix-profile/bin` is in your PATH:

```bash
# Check if nix-profile/bin is in PATH
echo $PATH | tr ':' '\n' | grep nix-profile

# If not found, add to your shell config (~/.bashrc, ~/.zshrc, etc.)
export PATH="$HOME/.nix-profile/bin:$PATH"
```

### Node.js requirement

Cortex CLI requires Node.js 18+. This package bundles Node.js 22 LTS, so you don't need to install Node.js separately. The wrapper script automatically uses the bundled Node.js runtime.

### Permission issues

On macOS, you may need to grant terminal permissions for Cortex CLI to access certain features. This is a macOS security feature and is not specific to the Nix package.

## Comparison with Official Installer

| Aspect | Official Installer | This Nix Flake |
|--------|-------------------|----------------|
| **Installation** | `curl ... \| sh` | `nix profile install` |
| **Updates** | Manual re-install | `nix profile upgrade --all` |
| **Rollback** | ❌ Not possible | ✅ `nix profile rollback` |
| **Declarative** | ❌ No | ✅ NixOS/Home Manager |
| **Reproducible** | ⚠️ May vary | ✅ Hash-verified |
| **Multi-version** | ❌ One at a time | ✅ Multiple profiles |
| **Cleanup** | Manual removal | `nix-collect-garbage` |

**Choose official installer if**: You want the simplest setup or don't use Nix.

**Choose this flake if**: You use NixOS/Home Manager, need version control, want reproducibility, or prefer declarative configuration.

## Why Not Just Use the Official Installer?

While `curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh` works, it has limitations:

- **Not Declarative**: Can't be managed in your Nix configuration
- **No Rollback**: Can't easily revert to previous versions
- **Manual Updates**: Need to re-run the installer script
- **Outside Nix**: Doesn't integrate with Nix's dependency management
- **No Version Pinning**: Always installs the latest version

This Nix flake solves all these issues while maintaining compatibility with Snowflake's official distribution.

## License

The Nix packaging is MIT licensed. Cortex Code CLI itself is proprietary software by Snowflake.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Setting Up for Development

1. Fork this repository
2. Make your changes
3. Test locally with `nix build`
4. Submit a pull request

### Reporting Issues

If you encounter issues:
1. Check existing GitHub issues
2. Verify your Nix installation is up to date
3. Try rebuilding with `nix build --rebuild`
4. Report the issue with full error output

## Acknowledgments

This package is inspired by [claude-code-nix](https://github.com/sadjow/claude-code-nix) and follows similar patterns for automated updates and distribution.
