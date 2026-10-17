{
  description = "UEFI chain-loader for systemd-boot that boots bootmgfw.efi from a specific GPT partition pinned at compile-time";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.rust-overlay = {
    url = "github:oxalica/rust-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }: {
    nixosModules.default = { lib, pkgs, config, ... }:
      let
        rustBin = rust-overlay.lib.mkRustBin { } pkgs;
        rustToolchain = rustBin.fromRustupToolchainFile ./rust-toolchain.toml;
      in
      import ./default.nix {
        inherit lib pkgs config;
        toolchain = rustToolchain;
      };

    # Test system for ci
    checks.x86_64-linux.module =
      let
        system = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.default
            {
              boot.loader.systemd-boot.enable = true;
              boot.loader.systemd-boot.winchain = {
                enable = true;
                partuuid = "00000000-0000-0000-0000-000000000000";
              };
              fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
              system.stateVersion = "26.05";
            }
          ];
        };
        efi = system.config.boot.loader.systemd-boot.extraFiles."efi/shims/winchain.efi";
      in
      nixpkgs.legacyPackages.x86_64-linux.runCommand "winchain-module" { } ''
        test -s ${efi}
        touch $out
      '';
  };
}
