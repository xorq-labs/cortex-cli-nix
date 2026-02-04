#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly S3_BASE_URL="https://sfc-repo.snowflakecomputing.com/cortex-code-cli/a4643c4278"
readonly VERSION_FILE="stable_version.txt"

# Platform names used by Snowflake
readonly PLATFORMS=("darwin-arm64" "darwin-amd64" "linux-amd64" "linux-arm64")

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

url_encode() {
    local string="$1"
    echo "$string" | sed 's/+/%2B/g'
}

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1 || echo "unknown"
}

get_latest_version() {
    local version_url="${S3_BASE_URL}/${VERSION_FILE}"
    local version=$(curl -fsSL "$version_url" 2>&1 | tr -d '[:space:]')
    if [ -z "$version" ]; then
        log_error "Failed to fetch version from $version_url"
        return 1
    fi
    echo "$version"
}

fetch_manifest() {
    local version="$1"
    local encoded_version=$(url_encode "$version")
    local manifest_url="${S3_BASE_URL}/${encoded_version}/manifest.json"

    local manifest=$(curl -fsSL "$manifest_url" 2>&1)
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch manifest from $manifest_url"
        return 1
    fi
    echo "$manifest"
}

extract_checksum() {
    local manifest="$1"
    local os="$2"
    local arch="$3"

    # Extract checksum using jq or fallback to sed/grep
    if command -v jq >/dev/null 2>&1; then
        echo "$manifest" | jq -r ".packages.${os}.${arch}.checksum"
    else
        # Simple grep/sed fallback
        echo "$manifest" | grep -A 2 "\"${os}\"" | grep -A 1 "\"${arch}\"" | grep "checksum" | sed -n 's/.*"checksum":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
    fi
}

update_package_version() {
    local version="$1"
    # Escape + for sed
    local escaped_version=$(echo "$version" | sed 's/+/\\+/g')
    sed -i.bak "s/version = \".*\"/version = \"$version\"/" package.nix
}

update_hash() {
    local platform="$1"
    local hash="$2"
    local temp_file=$(mktemp)

    # Update the specific platform hash
    awk -v platform="$platform" -v hash="$hash" '
        /hashes = \{/ { in_hash_block=1 }
        in_hash_block && $0 ~ "\"" platform "\"" {
            sub(/= "[^"]*"/, "= \"" hash "\"")
        }
        in_hash_block && /^[[:space:]]*\};/ { in_hash_block=0 }
        { print }
    ' package.nix > "$temp_file"
    mv "$temp_file" package.nix
}

cleanup_backup_files() {
    rm -f package.nix.bak
}

update_to_version() {
    local new_version="$1"

    log_info "Updating to version $new_version..."

    # Fetch manifest
    log_info "Fetching manifest..."
    local manifest=$(fetch_manifest "$new_version")
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch manifest"
        exit 1
    fi

    # Update version in package.nix
    update_package_version "$new_version"

    # Update hashes for all platforms
    log_info "Fetching checksums for all platforms..."
    for platform in "${PLATFORMS[@]}"; do
        # Split platform into os and arch (e.g., "darwin-arm64" -> "darwin" "arm64")
        local os=$(echo "$platform" | cut -d'-' -f1)
        local arch=$(echo "$platform" | cut -d'-' -f2)

        log_info "  Fetching checksum for $platform..."
        local checksum=$(extract_checksum "$manifest" "$os" "$arch")

        if [ -z "$checksum" ] || [ "$checksum" = "null" ]; then
            log_error "Failed to fetch checksum for $platform"
            mv package.nix.bak package.nix
            exit 1
        fi

        log_info "  $platform: $checksum"
        update_hash "$platform" "$checksum"
    done

    cleanup_backup_files

    log_info "Verifying build..."
    if ! nix build .#cortex-cli > /dev/null 2>&1; then
        log_error "Build verification failed"
        return 1
    fi

    log_info "✅ Build successful!"
    return 0
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "package.nix" ]; then
        log_error "flake.nix or package.nix not found. Please run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to specific version"
    echo "  --check           Only check for updates, don't apply"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update to latest version"
    echo "  $0 --check            # Check if update is available"
    echo "  $0 --version 1.0.5+022417.2cafbd3cf8db   # Update to specific version"
}

parse_arguments() {
    local target_version=""
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                target_version="$2"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    echo "$target_version|$check_only"
}

update_flake_lock() {
    if command -v nix >/dev/null 2>&1; then
        log_info "Updating flake.lock..."
        nix flake update
    fi
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat package.nix flake.lock 2>/dev/null || true
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local args=$(parse_arguments "$@")
    local target_version=$(echo "$args" | cut -d'|' -f1)
    local check_only=$(echo "$args" | cut -d'|' -f2)

    local current_version=$(get_current_version)
    local latest_version

    if [ -n "$target_version" ]; then
        latest_version="$target_version"
    else
        latest_version=$(get_latest_version) || {
            log_error "Failed to fetch latest version"
            exit 1
        }
    fi

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date!"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version → $latest_version"
        exit 1  # Exit with non-zero to indicate update is available
    fi

    update_to_version "$latest_version"

    log_info "Successfully updated cortex-cli from $current_version to $latest_version"

    update_flake_lock
    show_changes
}

main "$@"
