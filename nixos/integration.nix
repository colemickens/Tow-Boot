{ evalTowBoot }:

{ config, pkgs, lib, ... }:

# TODO:
# - no idea if this entire premise is even acceptable to TB upstream
# - there's no rollback, not even a backup made right now

let
  _cfg = config.tow-boot;
  cfg = builtins.trace "x${pkgs.path}" _cfg;
  towbootEval = evalTowBoot {
    inherit (cfg) device config system;
  };
  towbootBuild = towbootEval.config.Tow-Boot;
in
{
  options = {
    tow-boot = {
      enable = lib.mkEnableOption "tow-boot integration";
      autoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      system = lib.mkOption {
        type = lib.types.anything;
        default = pkgs.hostPlatform.system;
      };
      device = lib.mkOption {
        type = lib.types.str;
        default = null;
      };
      config = lib.mkOption {
        type = lib.types.attrs;
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    ({
      system.build.tow-boot = towbootBuild;
    })
    (lib.mkIf (cfg.device == "raspberryPi-aarch64") {
    system.activationScripts.towbootUpdate = lib.mkIf cfg.autoUpdate {
      text = ''
        "${towbootBuild.outputs.extra.scripts}/bin/tow-boot-rpi-update-firmware"
      '';
      deps = [ ];
    };

    environment.systemPackages = with pkgs; [] ++
      (builtins.attrValues towbootBuild.outputs.extra)
    ;

    # fileSystems = {
    #   "/boot/firmware" = {
    #     # TODO: reconsider this, use `TOW-BOOT-FI` ?
    #     # (but I've not done this because I want to use rpi4
    #     #  to bootstrap rpi3 and need to potentially have
    #     #  both addressable)
    #     device = "/dev/disk/by-partuuid/${mbr_disk_id}-01";
    #     format = "vfat";
    #   };
    # };
    })
  ]);
}
