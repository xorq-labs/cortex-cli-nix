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
  version = "1.1.41+225157.0f36395f58d3";

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
    "darwin-arm64" = "dd2992f94adcfa5d79538fad503c31eaf7d591b8e48532ee9388b3538719b2ac";
    "darwin-amd64" = "9ed89eabfea923c3fd008abf0b58a126008125bc89944faec7e0ea8b76252d52";
    "linux-amd64" = "be14ecd0be461891c7cd3b68bcb1a731e1a69da9fcd278f647fd1340a212efe4";
    "linux-arm64" = "f0147dee168bf53811de8fb55cb9d1f69a5e92fa7957ff42d7d4d802446fc13b";
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
