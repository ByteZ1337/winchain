{
  description = "UEFI chain-loader for systemd-boot that boots bootmgfw.efi from a specific GPT partition pinned at compile-time";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.rust-overlay = {
    url = "github:oxalica/rust-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { rust-overlay, ... }: {
    nixosModules.winchain = { lib, pkgs, config, ... }:
      let
        rustBin = rust-overlay.lib.mkRustBin { } pkgs;
        rustToolchain = rustBin.fromRustupToolchainFile ./rust-toolchain.toml;
      in
      import ./default.nix {
        inherit lib pkgs config;
        toolchain = rustToolchain;
      };
  };
}