# cortex-cli-nix

Nix package for [Snowflake Cortex Code CLI](https://ai.snowflake.com/) - AI coding assistant in your terminal.

**🚀 Automatically updated hourly** via GitHub Actions.

## Quick Start

```bash
# Try it now (no installation)
nix run github:xorq-labs/cortex-cli-nix

# Install to your system
nix profile install github:xorq-labs/cortex-cli-nix

# Verify
cortex --version
```

## Features

- **Always up-to-date**: Hourly automated version checks
- **Pre-built binaries**: Cachix cache for instant installation
- **Node.js 22 bundled**: No runtime dependencies needed
- **Multi-platform**: macOS (ARM64/Intel) and Linux (x86_64/ARM64)
- **Version pinning**: Git tags for reproducible builds

## Installation

### Standalone (nix profile)

```bash
# Install
nix profile install github:xorq-labs/cortex-cli-nix

# Update
nix profile upgrade '.*cortex-cli.*'

# Rollback
nix profile rollback

# Uninstall
nix profile remove '.*cortex-cli.*'
```

### NixOS/Home Manager

```nix
{
  inputs.cortex-cli.url = "github:xorq-labs/cortex-cli-nix";

  # Add to your configuration:
  nixpkgs.overlays = [ cortex-cli.overlays.default ];
  environment.systemPackages = [ pkgs.cortex-cli ];  # NixOS
  home.packages = [ pkgs.cortex-cli ];              # Home Manager
}
```

### Binary Cache (Optional)

```bash
cachix use xorq-labs
```

Or in your configuration:

```nix
nix.settings = {
  substituters = [ "https://xorq-labs.cachix.org" ];
  trusted-public-keys = [ "xorq-labs.cachix.org-1:yw5TptZAA4ry8WZ8VEAy4e4T8bdIhoeiLC5YlR5cOo4=" ];
};
```

## Version Pinning

Use git refs to pin specific versions:

| Tag | Example | Updates |
|-----|---------|---------|
| `vX.Y.Z+BUILD.HASH` | `v1.0.5+022417.2cafbd3cf8db` | Never (exact) |
| `vX.Y.Z` | `v1.0.5` | New builds only |
| `vX` | `v1` | Latest in major version |
| `latest` | `latest` | Always newest |

**Usage:**

```bash
# Pin to exact version
nix run github:xorq-labs/cortex-cli-nix?ref=v1.0.5+022417.2cafbd3cf8db

# Track v1.0.5 (auto-updates to new builds)
nix run github:xorq-labs/cortex-cli-nix?ref=v1.0.5

# Track latest v1.x
nix run github:xorq-labs/cortex-cli-nix?ref=v1
```

**In flake inputs:**

```nix
inputs.cortex-cli.url = "github:xorq-labs/cortex-cli-nix?ref=v1.0.5";
```

Tags are automatically created within 1 hour of each release.

## Why This Flake?

Advantages over official installer (`curl ... | sh`):

- ✅ Declarative configuration (NixOS/Home Manager)
- ✅ Version pinning and rollbacks
- ✅ Reproducible builds with hash verification
- ✅ Automatic updates via `nix profile upgrade`
- ✅ No manual cleanup needed

## Technical Details

**Distribution:** Snowflake S3 bucket (not npm)
- Base URL: `https://sfc-repo.snowflakecomputing.com/cortex-code-cli/a4643c4278/`
- Version format: `MAJOR.MINOR.PATCH+BUILD.HASH` (e.g., `1.0.5+022417.2cafbd3cf8db`)
- Platforms: darwin-arm64, darwin-amd64, linux-amd64, linux-arm64

**Package:** Pre-built tarballs + Node.js 22 LTS wrapper

## Development

```bash
git clone https://github.com/xorq-labs/cortex-cli-nix
cd cortex-cli-nix

nix build                              # Build package
nix run . -- --version                 # Test
./scripts/update-version.sh --check    # Check for updates
nix develop                            # Dev shell
```

## Troubleshooting

**Command not found?** Ensure `~/.nix-profile/bin` is in your PATH:

```bash
export PATH="$HOME/.nix-profile/bin:$PATH"
```

**Node.js requirement:** Bundled with package (Node.js 22 LTS), no separate install needed.

## License

Nix packaging: MIT
Cortex Code CLI: Proprietary (Snowflake)

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
