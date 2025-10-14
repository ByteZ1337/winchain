{ lib, pkgs, config, toolchain, ... }:

let
  inherit (lib) mkOption mkIf mkMerge mkDefault types optionalString;
  cfg = config.boot.loader.systemd-boot.winchain;

  mkWinchain = pkgs.callPackage ./package.nix {
    partuuid = cfg.partuuid or (throw "winchain: set boot.loader.systemd-boot.winchain.partuuid to the PARTUUID of the Windows ESP");
    toolchain = toolchain;
  };

  systemdEntry = ''
    title ${cfg.title}
    efi ${cfg.outPath}
    ${optionalString (cfg.sortKey != null) "sort-key ${cfg.sortKey}"}
  '';
in
{
  options.boot.loader.systemd-boot.winchain = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the winchain UEFI chain-loader for systemd-boot";
    };
    partuuid = mkOption {
      type = types.str;
      default = null;
      description = "The GPT PARTUUID of the Windows ESP";
    };
    title = mkOption {
      type = types.str;
      default = "Windows";
      description = "systemd-boot menu title";
    };
    sortKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional systemd-boot sort-key for the entry";
    };
    outPath = mkOption {
      type = types.str;
      default = "efi/shims/winchain.efi";
      description = "The path to install winchain.efi to (on the systemd-boot ESP)";
    };
  };

  config = mkMerge [
    (mkIf (cfg.partuuid != null) {
      boot.loader.systemd-boot.winchain.enable = mkDefault true;
    })

    (mkIf cfg.enable {
      boot.loader.systemd-boot = {
        extraFiles."${cfg.outPath}" = "${mkWinchain}/bin/winchain.efi";
        extraEntries."${cfg.title}.conf" = systemdEntry;
      };
    })
  ];
}