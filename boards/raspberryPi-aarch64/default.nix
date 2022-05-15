{ config, lib, pkgs, inputs, ... }:

let
  cfg = {
    use_upstream = true;
    dtoverlay = "disable-bt";
  };
  
  rpipkgs = import inputs.rpipkgs {
    system = pkgs.system;
  };
  
  final_binary = "Tow-Boot.noenv.rpi_arm64.bin";
  configTxt = pkgs.writeText "config.txt" ''
    # these apply to all, but can be overridden by device specific sections
    arm_64bit=1
    enable_uart=1
    avoid_warnings=1
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    hdmi_force_hotplug=1
    # TODO:?
    arm_boost=1
    kernel=${final_binary}
    dtoverlay=${cfg.dtoverlay}
    ${lib.optional (cfg.use_upstream) ''
      upstream_kernel=1
    ''}
    avoid_warnings=1
    
    uart_2ndstage=1

    # TODO: my USB wait thingy? or did new eeprom
    # and firmware fix this?
    # -- could just be that trying the USB-MSD first
    # -- gives the SSD enough time to be up...?

    #dtparam=watchdog
  '';
  # BOOT_ORDER: (pi reads the hex value RTL (LSB=>MSB))
  # 0x0 = SD-CARD-DETECT
  # 0x1 = SD-CARD
  # 0x2 = NETWORK
  # 0x3 = RPIBOOT
  # 0x4 = USB-MSD
  # 0x4 = BCM-USB-MSD
  # 0x4 = NVME
  # 0x4 = STOP
  # 0x4 = RESTART
  bootconfTxt = pkgs.writeText "bootconf.txt" ''
    [all]
    BOOT_UART=1
    ENABLE_SELF_UPDATE=1
    BOOT_ORDER=0xf2146 # NVME => USB-MSB => SD-CARD => NETWORK => RESTART
  '';
  eepromBin = pkgs.runCommandNoCC "pieeprom.bin" {} ''
    set -x
    set -euo pipefail

    dir="${rpipkgs.raspberrypi-eeprom}/share/rpi-eeprom/stable"
    orig="$(ls $dir | grep pieeprom | sort | tail -1)"

    ${rpipkgs.raspberrypi-eeprom}/bin/rpi-eeprom-config \
      --config "${bootconfTxt}" \
      --out $out \
        "$(readlink -f $dir/$orig)"
  '';
in {
  # TODO: and like why is this not passed through?
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
    defconfig = lib.mkDefault "rpi_arm64_defconfig";
    config = [
      (helpers: with helpers; {
        CMD_POWEROFF = no;
      })
    ];
    patches = [
      ./0001-configs-rpi-allow-for-bigger-kernels.patch
      ./0001-Tow-Boot-rpi-Increase-malloc-pool-up-to-64MiB-env.patch
      ./0001-rpi-Copy-properties-from-firmware-dtb-to-the-loaded-.patch

      # Remove when updating to 2022.01
      # https://patchwork.ozlabs.org/project/uboot/list/?series=273129&archive=both&state=*
      ./1-2-rpi-Update-the-Raspberry-Pi-doucmentation-URL.patch
    ];
    outputs.scripts = pkgs.symlinkJoin {
      name = "tow-boot-${config.device.identifier}-scripts";
      paths = [
        (pkgs.writeShellScriptBin "tow-boot-rpi-update" ''
          set -x
          set -euo pipefail

          #
          # FIND + REMOUNT FIRMWARE (pull this to common script?)
          # TODO: mount firmware by the partition-id
          sudo mount -o remount,rw /boot/firmware

          #
          # UPDATE EEPROM
          sudo ${rpipkgs.raspberrypi-eeprom}/bin/rpi-eeprom-update -r || true
          sudo env BOOTFS=/boot/firmware \
            ${rpipkgs.raspberrypi-eeprom}/bin/rpi-eeprom-update \
              -d -f "${eepromBin}"

          #
          # UPDATE FIRMWARE + TOW-BOOT

          # TODO: copy other files too...

          # TODO: assert files are here, since they might move ("binaries" dir)

          # TODO: `outputs.firmware` -> `outputs.bootloader` and then it passthru's outputs.firmware which
          # contains the rpi stage-0 start4.elf, etc

          cp -av "${config.Tow-Boot.outputs.firmware}/binaries/"* "/boot/firmware/"
          cp -av "${configTxt}" "/boot/firmware/config.txt.$(date +'%s')"
          cp -av "${configTxt}" "/boot/firmware/config.txt"

          # TODO: if we need a reboot, maybe write a sentinel indicating such

          #
          # if not need update:
          # - check for /boot/firmware/old, delete it
          # TODO
          # - unmount firmware
          # otherwise:

          printf "!!!\n!!!\nPLEASE REBOOT\n!!!\n!!!"
        '')
      ];
    };

    #TODO: refactor this to output all firmware to FIRMWARE_CONTENTS/
    # TODO: refactor the populate commands to copy from ${outputs.firmware}/FIRMARE_CONTENTS
    # outputs.firmware = lib.mkIf (config.device.identifier == "raspberryPi-aarch64") (
    #   pkgs.callPackage (
    #     { runCommandNoCC }:

    #     runCommandNoCC "tow-boot-${config.device.identifier}" {} ''
    #       (PS4=" $ "; set -x
    #       mkdir -p $out/{binaries,config}
    #       cp -v ${config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin $out/binaries/Tow-Boot.noenv.bin
    #       cp -v ${config.Tow-Boot.outputs.firmware}/config/noenv.config $out/config/noenv.config
    #       )
    #     ''
    #   ) { }
    # );
    builder.installPhase = ''
      cp -v u-boot.bin $out/binaries/${final_binary}
    '';

    # TODO: why is there "outputs.firmware", "installerPhase" AND "populateCommands"... ?


    # TODO: this option name is confusing given the lines below it literally
    # "write" the binary into the firmware part (but I suspect "write" vs "copy" is the key)
    # The Raspberry Pi firmware expects a filesystem to be used.
    writeBinaryToFirmwarePartition = false;

    diskImage = {
      partitioningScheme = "mbr"; # why? the rpi boots fine from gpt, we should use it?
      # except rpithreeb?
    };
    firmwarePartition = {
      partitionType = "0C";
      filesystem = {
        filesystem = "fat32";
        populateCommands = ''
          cp -v ${configTxt} config.txt
          ${if cfg.use_upstream then ''
            mkdir -p upstream/
            cp -v ${config.Tow-Boot.outputs.firmware}/binaries/${final_binary} upstream/${final_binary}
          '' else ''
            cp -v ${config.Tow-Boot.outputs.firmware}/binaries/${final_binary} ${final_binary}
          ''} 
          cp -v ${rpipkgs.raspberrypi-armstubs}/armstub8-gic.bin armstub8-gic.bin
          (
          target="$PWD"
          cd ${rpipkgs.raspberrypifw}/share/raspberrypi/boot
          cp -v bootcode.bin fixup*.dat start*.elf "$target/"
          cp -r overlays "$target/"

          cp -v ${rpipkgs.linuxPackages_latest.kernel}/dtbs/broadcom/bcm*rpi*.dtb "$target/upstream/"
          cp -v ${rpipkgs.linuxPackages_rpi4.kernel}/dtbs/broadcom/bcm*rpi*.dtb "$target/"
          )
        '';

        # The build, since it includes misc. files from the Raspberry Pi Foundation
        # can get quite bigger, compared to other boards.
        size = 32 * 1024 * 1024;
        fat32 = {
          partitionID = "00F800F8";
        };
        label = "TOWBOOT-FW";
      };
    };
  };
  documentation.sections.installationInstructions = ''
    ## Installation instructions

    ${config.documentation.helpers.genericSharedStorageInstructionsTemplate { storage = "an SD card, USB drive (if the Raspberry Pi is configured correctly) or eMMC (for systems with eMMC)"; }}
  '';
}
