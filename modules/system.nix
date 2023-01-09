{ config, lib, pkgs, ... }:

let
  cfg = config.system;
in
{
  options = {
    system = {
      automaticCross = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enables automatic configuration of cross-compilation.

          **Note** that while it is disabled by default, the default.nix at the
          root of the project _will_ enable it.
        '';
      };
      system = lib.mkOption {
        # Known supported target types
        type = lib.types.enum [
          "i686-linux"
          "x86_64-linux"
          "armv5tel-linux"
          "armv6l-linux"
          "armv7l-linux"
          "aarch64-linux"
        ];
        description = ''
          Defines the kind of target architecture system the device is.
        '';
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = pkgs.targetPlatform.system == cfg.system;
        message = ''
          pkgs.targetPlatform.system expected to be `${cfg.system}`, is `${pkgs.targetPlatform.system}`.
            TIP: enable `system.automaticCross`, which will impurely automatically enable cross-compilation.
        '';
      }
    ];
  };
}

