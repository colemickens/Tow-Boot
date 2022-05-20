{}:

# TODO:
# - no idea if this entire premise is even acceptable to TB upstream
# - there's no rollback, not even a backup made right now
    
let
  cfg = {};

  towbootBuild = import device {
    deviceCfg = cfg;
  };

  updateInPlace = pkgs.writeShellScriptBin "towboot-${device}-update-in-place" ''

  '';
{
  options = {
    # deviceName
    # deviceConfig
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.towbootUpdate = lib.mkIf cfg.autoupdate {
      text = updateInPlaceScript;
      deps = [];
    };

    environment.systemPackages = [
      updateInPlace
    ];
  
    fileSystems = {
      "/boot/firmware" = {
        # TODO: reconsider this, use `TOW-BOOT-FI` ?
        # (but I've not done this because I want to use rpi4
        #  to bootstrap rpi3 and need to potentially have
        #  both addressable)
        device = "/dev/disk/by-partuuid/${mbr_disk_id}-01";
        format = "vfat";
      };
    };
  };
}
