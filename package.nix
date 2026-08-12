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
  version = "1.1.65+211353.f096733670be";

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
    "darwin-arm64" = "30a93fcc78b08b2ecfb96a695578e1b0ccd4e208df339fcb891b2bc2f4ba1e9f";
    "darwin-amd64" = "5b534f5ff7431f69724aa33354356d49a9a4277824057f93e9bda55e11dd372b";
    "linux-amd64" = "3d5743c16936d24d941005718eb8770e8da53f7577d923874d8ab10913efee0e";
    "linux-arm64" = "c8c59a8f8e8e0dd7ed9dc990f14eb9168db86129fd5622f95aa0d57a9a0c3f0c";
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
