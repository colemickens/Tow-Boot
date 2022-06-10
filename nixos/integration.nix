{ config, pkgs, lib, inputs, ... }:

# TODO:
# - no idea if this entire premise is even acceptable to TB upstream
# - there's no rollback, not even a backup made right now

let
  cfg = config.tow-boot;
  tb = inputs.tow-boot;
  towbootBuild =
    let
      devBuilder = tb.devicesWith.${pkgs.system}.${cfg.device};
      userConfig = {
        configuration = {
          config = {
            Tow-Boot = cfg.config;
          };
        };
      };
    in
      (devBuilder userConfig);
  tbOutputs = towbootBuild.config.Tow-Boot.outputs;
in
{
  options = {
    tow-boot = {
      enable = lib.mkEnableOption "tow-boot integration";
      autoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      device = lib.mkOption {
        type = lib.types.str;
        default = "raspberryPi-aarch64";
      };
      config = lib.mkOption {
        # type = lib.types.attrsOf lib.types.anything;
        type = lib.types.anything;
        default = {};
      };
    };
  };

  config = lib.mkIf cfg.enable {
    system.build.towbootBuild = towbootBuild;

    system.activationScripts.towbootUpdate = lib.mkIf cfg.autoUpdate {
      text = ''
        "${tbOutputs.extra.scripts}/bin/tow-boot-rpi-update-firmware"
      '';
      deps = [ ];
    };

    environment.systemPackages = with pkgs; [] ++
      (builtins.attrValues tbOutputs.extra)
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
  };
}
