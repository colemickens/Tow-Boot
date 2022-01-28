{ config, lib, pkgs, ... }:

# TODO: redesign feedback
# - I can't combine armv6l and aarch64 :/
# - I really don't understand some choices

let
  inherit (config.helpers)
    composeConfig
  ;
  raspberryPi = composeConfig {
    config = {
      device.identifier = "raspberryPi";
      Tow-Boot.defconfig = "rpi_defconfig";
    };
  };
  raspberryPi-aarch64 = composeConfig {
    config = {
      device.identifier = "raspberryPi-aarch64";
      Tow-Boot.defconfig = "rpi_arm64_defconfig";
    };
  };

  configTxt = pkgs.writeText "config.txt" ''
    # these apply to all, but can be overridden by device specific sections
    arm_64bit=1
    enable_uart=1
    avoid_warnings=1

    [pi0]
    kernel=Tow-Boot.noenv.rpi.bin
    arm_64bit=0

    [pi02]
    kernel=Tow-Boot.noenv.rpi_arm64.bin

    [pi3]
    kernel=Tow-Boot.noenv.rpi_arm64.bin

    [pi4]
    kernel=Tow-Boot.noenv.rpi_arm64.bin
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    arm_boost=1

    # override all filters and apply to all boards
    [all]
    avoid_warnings
  '';
in
{
  device = {
    manufacturer = "Raspberry Pi";
    name = "Combined AArch64";
    identifier = lib.mkDefault "raspberryPi-aarch64";
    productPageURL = "https://www.raspberrypi.com/products/";
  };

  hardware = {
    # Targets multiple broadcom SoCs
    soc = "generic-aarch64";
  };

  Tow-Boot = {
    # FIXME: a small lie for now until we get the upcoming changes in.
    defconfig = lib.mkDefault "rpi_arm64_defconfig";

    config = [
      (helpers: with helpers; {
        CMD_POWEROFF = no;
      })
    ];
    patches = [
      ./0001-configs-rpi-allow-for-bigger-kernels.patch
      ./0001-Tow-Boot-rpi-Increase-malloc-pool-up-to-64MiB-env.patch
      
      # Remove when updating to 2022.01
      # https://patchwork.ozlabs.org/project/uboot/list/?series=273129&archive=both&state=*
      ./1-2-rpi-Update-the-Raspberry-Pi-doucmentation-URL.patch

      # TODO: write this patch
      ./0001-Tow-Boot-pass-uboot-version-in-kernel-params.patch
    ];
    outputs.firmware = lib.mkIf (config.device.identifier == "raspberryPi-aarch64") (
      pkgs.callPackage (
        { runCommandNoCC }:

        runCommandNoCC "tow-boot-${config.device.identifier}" {
          inherit (raspberryPi-3.config.Tow-Boot.outputs.firmware)
            version
            source
          ;
        } ''
          (PS4=" $ "; set -x
          mkdir -p $out/{binaries,config}
          cp -v ${raspberryPi-3.config.Tow-Boot.outputs.firmware.source}/* $out/
          cp -v ${raspberryPi-3.config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin $out/binaries/Tow-Boot.noenv.rpi3.bin
          cp -v ${raspberryPi-3.config.Tow-Boot.outputs.firmware}/config/noenv.config $out/config/noenv.rpi3.config

          cp -v ${raspberryPi-4.config.Tow-Boot.outputs.firmware.source}/* $out/
          cp -v ${raspberryPi-4.config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin $out/binaries/Tow-Boot.noenv.rpi4.bin
          cp -v ${raspberryPi-4.config.Tow-Boot.outputs.firmware}/config/noenv.config $out/config/noenv.rpi4.config
          )
        ''
      ) { }
    );
    builder.installPhase = ''
      cp -v u-boot.bin $out/binaries/Tow-Boot.$variant.bin
    '';

    # TODO: why is there "outputs.firmware", "installerPhase" AND "populateCommands"... ?

    # The Raspberry Pi firmware expects a filesystem to be used.
    writeBinaryToFirmwarePartition = false;

    diskImage = {
      partitioningScheme = "mbr"; # why? the rpi boots fine from gpt, we should use it?
    };
    firmwarePartition = {
      partitionType = "0C";
      filesystem = {
        filesystem = "fat32";
        populateCommands = ''
          cp -v ${configTxt} config.txt
          cp -v ${raspberryPi-3.config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin Tow-Boot.noenv.rpi3.bin
          cp -v ${raspberryPi-4.config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin Tow-Boot.noenv.rpi4.bin
          cp -v ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin armstub8-gic.bin
          (
          target="$PWD"
          cd ${pkgs.raspberrypifw}/share/raspberrypi/boot
          cp -v bcm2711-rpi-4-b.dtb "$target/"
          cp -v bootcode.bin fixup*.dat start*.elf "$target/"
          )
        '';

        # The build, since it includes misc. files from the Raspberry Pi Foundation
        # can get quite bigger, compared to other boards.
        size = 32 * 1024 * 1024;
        fat32 = {
          partitionID = "00F800F8";
        };
        label = "TOW-BOOT-FIRM";
      };
    };
  };
  documentation.sections.installationInstructions = ''
    ## Installation instructions

    ${config.documentation.helpers.genericSharedStorageInstructionsTemplate { storage = "an SD card, USB drive (if the Raspberry Pi is configured correctly) or eMMC (for systems with eMMC)"; }}
  '';
}
