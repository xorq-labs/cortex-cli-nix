# Snowflake Cortex Code CLI (coco) Package
#
# This package installs Snowflake's Cortex Code CLI assistant
# Requires Node.js 18+ (bundled)

{ lib
, stdenv
, fetchurl
, nodejs_22
, cacert
, bash
}:

let
  version = "1.1.15+215415.6cb780bd8e71";

  # Platform mapping (Nix system -> Snowflake platform naming)
  platformMap = {
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-amd64";
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-arm64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  # SHA256 hashes per platform
  hashes = {
    "darwin-arm64" = "e7af541620b1f7aa2d28d98cf1607665dd1350406c82cb7e6e0c6498e46dfa5c";
    "darwin-amd64" = "631f3d0c041e2f470e99e9ec8fe9410dca581e8952acfa56f6f4bd143d59c226";
    "linux-amd64" = "442f31a1d6d6e09294ab1f463853db0e171c10756043637e1b414c7ba7af2ae6";
    "linux-arm64" = "a54b0728e27b5b236b0f65586ad3162c424ed512c7d74fe2632d09ba8803fa84";
  };

  # URL encode the version (replace + with %2B)
  urlEncodedVersion = builtins.replaceStrings ["+"] ["%2B"] version;

  # S3 distribution URL
  s3BaseUrl = "https://sfc-repo.snowflakecomputing.com/cortex-code-cli/a4643c4278";
  tarballName = "coco-${urlEncodedVersion}-${platform}.tar.gz";
  tarballUrl = "${s3BaseUrl}/${urlEncodedVersion}/${tarballName}";

  # Fetch the tarball
  src = fetchurl {
    url = tarballUrl;
    sha256 = hashes.${platform};
  };

in
assert platform != null ||
  throw "cortex-cli not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux";

stdenv.mkDerivation rec {
  pname = "cortex-cli";
  inherit version src;

  nativeBuildInputs = [ nodejs_22 cacert ];

  # Don't strip the binary - it's a Bun executable with bundled code
  dontStrip = true;

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Find the extracted directory
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d ! -name '.' | head -n 1)
    cd "$EXTRACTED_DIR"

    # Install to lib directory
    mkdir -p $out/lib/cortex-cli
    cp -r . $out/lib/cortex-cli/

    # Create wrapper script
    mkdir -p $out/bin
    cat > $out/bin/cortex << 'EOF'
#!${bash}/bin/bash
INSTALL_DIR="$out/lib/cortex-cli"

if [ -x "$INSTALL_DIR/cortex" ]; then
    exec "$INSTALL_DIR/cortex" "$@"
else
    echo "Error: Cortex Code executable not found" >&2
    exit 1
fi
EOF

    chmod +x $out/bin/cortex

    # Substitute paths
    substituteInPlace $out/bin/cortex \
      --replace-fail '$out' "$out"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Snowflake Cortex Code CLI - AI coding assistant";
    homepage = "https://ai.snowflake.com/";
    license = licenses.unfree;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "cortex";
    maintainers = [ ];
  };
}
