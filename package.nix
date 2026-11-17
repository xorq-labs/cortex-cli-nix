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
  version = "1.2.46+175654.6f8561fd271f";

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
    "darwin-arm64" = "76a37a37b432fa0b684d67efdaba0b2753b40d34924836a445f6597b24e665ee";
    "darwin-amd64" = "940f6853dbc9b8a57ae7cb046d589ae447d556b55be2bf8e71205bda05ea39d9";
    "linux-amd64" = "84b2ef93a25f2b73658bba219c15af53679911458f37eb550993ba06f1bf363f";
    "linux-arm64" = "bdc87770326123469b9d4b40e91f82d61ebf6ea58bfac0458a9f69ce50543394";
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
