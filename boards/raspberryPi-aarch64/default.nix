{ config, lib, pkgs, ... }:

let
  binary = "Tow-Boot.noenv.rpi_arm64.bin";
  inherit (config.helpers)
    composeConfig
  ;
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
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    arm_boost=1
    kernel=${binary}
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
    ];
    outputs.scripts = makeTheBundle {
      paths = [
        (pkgs.writeShellScript "tow-boot-rpi-update" ''
          #
          # FIND + REMOUNT FIRMWARE (pull this to common script?)
          sudo mount ...

          #
          # UPDATE EEPROM
          # TODO: check version+config to see if we need to do this
          sudo rpi-update-eeprom --firmware-path /tmp/mount-path

          #
          # UPDATE FIRMWARE + TOW-BOOT
          cp -av "${Tow-Boot.outputs.firmware}/*" "/tmp/mount-path"
          echo "rebooting in 30 seconds"

          # TODO: if we need a reboot, maybe write a sentinel indicating such

          #
          # if not need update:
          # - check for /boot/firmware/old, delete it
          # TODO
          # - unmount firmware
          # otherwise:
          echo "we need to update firmware, rebooting in 30 seconds..."
          sleep 20; echo "10 seconds..."; sleep 10
          sudo reboot
        '')
      ]
    };
    outputs.firmware = lib.mkIf (config.device.identifier == "raspberryPi-aarch64") (
      pkgs.callPackage (
        { runCommandNoCC }:

        runCommandNoCC "tow-boot-${config.device.identifier}" {
          inherit (config.Tow-Boot.outputs.firmware)
            version
            source
          ;
        } ''
          (PS4=" $ "; set -x
          mkdir -p $out/{binaries,config}
          cp -v ${config.Tow-Boot.outputs.firmware.source}/* $out/
          cp -v ${config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin $out/binaries/${binary}
          cp -v ${config.Tow-Boot.outputs.firmware}/config/noenv.config $out/config/noenv.rpi3.config
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
          cp -v ${config.Tow-Boot.outputs.firmware}/binaries/${binary} ${binary}
          cp -v ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin armstub8-gic.bin
          (
          target="$PWD"
          cd ${pkgs.raspberrypifw}/share/raspberrypi/boot
          cp -v bcm2711-rpi-*.dtb "$target/"
          mkdir -p "$target/upstream"
          cp -v ${pkgs.linuxPackages_latest.kernel}/dtbs/broadcom/bcm*rpi*.dtb "$target/upstream/"
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
