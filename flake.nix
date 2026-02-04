{
  description = "Nix package for Snowflake Cortex Code CLI - AI coding assistant";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        cortex-cli = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.cortex-cli;
          cortex-cli = pkgs.cortex-cli;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.cortex-cli}/bin/cortex";
          };
          cortex = {
            type = "app";
            program = "${pkgs.cortex-cli}/bin/cortex";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch-url
            cachix
            jq
          ];
        };
      }) // {
        overlays.default = overlay;
      };
}
