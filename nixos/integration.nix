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

  config = {
    activationScripts = mkIf autoUpdateInPlace {
      
    };

    environment.systemPackages = [
      updateInPlace
    ];
  };
}
