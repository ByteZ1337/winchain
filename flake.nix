{
  description = "UEFI chain-loader for systemd-boot that boots bootmgfw.efi from a specific GPT partition pinned at compile-time";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { ... }: {
    nixosModules.winchain = import ./default.nix;
  };
}