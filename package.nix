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
  version = "1.0.36+042036.5231ee8e1118";

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
    "darwin-arm64" = "7883a9d12e0cbfc16205c116215bf1d333f6476c459c1ffbb661e87088c73fd6";
    "darwin-amd64" = "27b0359d42f815957a7bed394939665fbcf586d309bfb37982fe9e25f07c365c";
    "linux-amd64" = "324fcca3ce6149ed2094a947c31a81190201ffb3e6ca52ede571824c3c5d7d14";
    "linux-arm64" = "c3cc88ab6487e5cc708b218fe9714d568b8ff05a9262e16ac24acc8aee42bf2b";
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
