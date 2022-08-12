{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.hardware.socs;
  starFiveSOCs = [ "starfive-jh7100" ];
  anyStarFive = lib.any (soc: config.hardware.socs.${soc}.enable) starFiveSOCs;

  _opensbi =
    let
      ubootBuild = config.Tow-Boot.outputs.firmware;
    in
    # pkgs.buildPackages.Tow-Boot.jh7100-opensbi.override {
    pkgs.buildPackages.Tow-Boot.systems.riscv64.jh7100-opensbi.override {
      withPayload = "${ubootBuild}/u-boot.bin";
      withFDT = "${ubootBuild}/u-boot.dtb";
    };

  # todo: should it even be listed in the overlay? I dont like using overlay for more tahn is needed
  fw_visionfive = pkgs.callPackage ../../../support/overlay/starfive-firmware/jh7100/firmware-visionfive/default.nix {
    opensbi = _opensbi;
  };
in
{
  options = {
    hardware.socs = {
      starfive-jh7100.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable when SoC is StarFive JH7100";
        internal = true;
      };
    };
  };

  config = mkMerge [
    {
      hardware.socList = starFiveSOCs;
    }
    (mkIf anyStarFive {
      system.system = "riscv64-linux";

      Tow-Boot = {
        defconfig = "starfive_jh7100_visionfive_smode_defconfig";
        # uBootVersion = "2022.07";
        useDefaultPatches = false;
        withLogo = false;

        # src = pkgs.fetchFromGitHub {
        #   owner = "NickCao";
        #   repo = "u-boot-starfive";
        #   rev = "ac75aa54020412a83b61dad46c5ea15e7f9f525c";
        #   sha256 = "1idh5k1479znp24rrfa0ikgk6iv5h80zscqhi6yv5ah4czia3ip3";
        # };
        src = pkgs.fetchFromGitHub {
          owner = "colemickens";
          repo = "u-boot";
          rev = "cdf764eaf6f5d3a3d5ea05b0f2f6d535d4ec1d47";
          sha256 = "sha256-C4NUnbPFwDwRkO9vCmbC0oi/Je3SdS27qNDm7SXoC2I=";
        };

        # I think for the most part we just want to leave
        # the tow/uboot build alone, most of what we need to do is build
        # custom opensbi and mush together after ward

        # consider:
        # - uboot: "upstream"/my-fork/nickcao's, fix up the boot var as per samueldr's comments
        # - 

        builder = {
          additionalArguments = {
            # secondBoot = "${pkgs.buildPackages.Tow-Boot.jh7100-secondBoot}/${pkgs.buildPackages.Tow-Boot.jh7100-secondBoot.name}.bin";
            # ddrinit = "${pkgs.buildPackages.Tow-Boot.jh7100-ddrinit}/${pkgs.buildPackages.Tow-Boot.jh7100-ddrinit.name}.bin";
          };
          # nativeBuildInputs = [];
          installPhase = ''
            cp -v u-boot.bin $out/u-boot.bin
            cp -v u-boot.dtb $out/u-boot.dtb
          '';
        };

        outputs = {
          extra = {
            scripts =
              let
                flashBootloaderExpect = pkgs.writeScript "visionfive-flashbootloader-expect.sh" ''
                  #!${pkgs.expect}/bin/expect -f
                  set timeout -1
                  spawn ${pkgs.picocom}/bin/picocom [lindex $argv 0] -b 115200 -s "${pkgs.lrzsz}/bin/sz -X"
                  expect "Terminal ready"
                  send_user "\n### Apply power to the VisionFive Board ###\n"
                  expect "bootloader"
                  expect "DDR"
                  send "\r"
                  expect "0:update uboot"
                  expect "select the function:"
                  send "0\r"
                  expect "send file by xmodem"
                  expect "CC"
                  send "\x01\x13"
                  expect "*** file:"
                  send "${fw_visionfive}/opensbi_u-boot_visionfive.bin"
                  send "\r"
                  expect "Transfer complete"
                '';
                flashBootloader = pkgs.writeScript "visionfive-flashbootloader.sh" ''
                  if $(groups | grep --quiet --word-regexp "dialout"); then
                    echo "User is in dialout group, flashing to board without sudo"
                    ${flashBootloaderExpect} $1
                  else
                    echo "User is not in dialout group, flashing to board with sudo"
                    sudo ${flashBootloaderExpect} $1
                  fi
                  sudo picocom -b 115200 $1
                '';
              in
              pkgs.buildEnv {
                name = "starfive-extras";
                paths = [
                  flashBootloader
                ];
              };
          };
        };
      };
    })

    # Documentation fragments
    (mkIf (anyStarFive) {
      documentation.sections.installationInstructions =
        lib.mkDefault
          (config.documentation.helpers.genericInstallationInstructionsTemplate {
            # StarFive will prefer SD card always.
            startupConflictNote = "";
          })
      ;
    })
  ];
}
