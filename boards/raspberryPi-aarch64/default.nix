{ config, lib, pkgs, inputs, ... }:

let
  toBooint = (v: if v then "1" else "0");
  cfg = {
    upstream_kernel = true;
    arm_boost = true;
    dtparam = "audio=on"; # "watchdog=on";
    dtoverlay = null;
    uart_2ndstage = true;
    hdmi_force_hotplug = true;
    hdmi_drive = 2;

    # TODO: allow users to: have custom tow-boot, with special parts per device
    # which is also how I want to handle some other things
    # plus (???) also isn't the the MBR device id? there's no such part id?

    # INTERNAL1: partitionID
    partitionID = "00F800F8";
    
    # INTERNAL2: latest u-boot
    useLatestUboot = true;
    etbc = {
      uBootVersion = "2022.04";
      useDefaultPatches = false;
      withLogo = false;
    };
    
    # INTERNAL3: unstable (master) firmware
    firmwarePackage = rpipkgs.raspberrypifw;
    mainlinePackage = rpipkgs.linuxPackages_latest;
  };
  cfgval = (f: p:
    let chk =
      if (builtins.hasAttr p cfg && cfg."${p}" != null)
      then (f cfg."${p}")
      else null;
    in (lib.optionalString (chk != null) "${p}=${chk}")
  );

  summaryTxt = pkgs.writeText "summary.txt" ''
    kernel='foo'
    firmwarePackage='bar'
  '';
  
  rpipkgs = import inputs.rpipkgs {
    system = pkgs.system;
  };

  final_binary = "Tow-Boot.noenv.rpi_arm64.bin";
  # ubootCommon = ''
  #   core_freq=250
  #   core_freq_min=250
  # '';
  ubootCommon = ''
    core_freq=400
    core_freq_min=400
  '';
  ubootPi4Common = ''
    dtoverlay=disable-bt
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
  '';
  configTxt =
    # https://www.raspberrypi.com/documentation/computers/config_txt.html#model-filters  
    pkgs.writeText "config.txt" ''
      # (implicit) all ########################################################
      arm_64bit=1
      enable_uart=1
      avoid_warnings=1
      kernel=${final_binary}
      ${cfgval toBooint "upstream_kernel"}
      ${cfgval toBooint "arm_boost"}
      ${cfgval toString "dtparam"}
      ${cfgval toString "dtoverlay"}
      ${cfgval toBooint "uart_2ndstage"}
      ${cfgval toBooint "hdmi_force_hotplug"}
      ${cfgval toString "hdmi_drive"}

      # TODO: pi3/pi02w might be broken because of:
      # - https://github.com/raspberrypi/firmware/issues/1696#issuecomment-1041298571
      # - if overlay is wrong, uart is wrong, u-boot/linux might do wrong thing
    
      # TODO: I think dtparams can come after dtoverlay -_- .... add it to the list

      [pi4]
      ${ubootPi4Common}
      [pi400]
      ${ubootPi4Common}
      [cm4]
      ${ubootPi4Common}
   
      [pi3]
      ${ubootCommon}
      [pi3+]
      ${ubootCommon}
      [pi02]
      ${ubootCommon}
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
  eepromBin = pkgs.runCommandNoCC "pieeprom.bin" { } ''
    set -x
    set -euo pipefail

    dir="${rpipkgs.raspberrypi-eeprom}/share/rpi-eeprom/stable"
    orig="$(ls $dir | grep pieeprom | sort | tail -1)"

    ${rpipkgs.raspberrypi-eeprom}/bin/rpi-eeprom-config \
      --config "${bootconfTxt}" \
      --out $out \
        "$(readlink -f $dir/$orig)"
  '';
in
{
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

  Tow-Boot = cfg.etbc // {
    defconfig = lib.mkDefault "rpi_arm64_defconfig";
    config = [
      (helpers: with helpers; {
        CMD_POWEROFF = no;
      })
    ];
    patches = [
      ./0001-configs-rpi-allow-for-bigger-kernels.patch
      # ./0001-Tow-Boot-rpi-Increase-malloc-pool-up-to-64MiB-env.patch
      ./0001-rpi-Copy-properties-from-firmware-dtb-to-the-loaded-.patch

      # Remove when updating to 2022.01
      # https://patchwork.ozlabs.org/project/uboot/list/?series=273129&archive=both&state=*
      # ./1-2-rpi-Update-the-Raspberry-Pi-doucmentation-URL.patch
    ];
    outputs.scripts = pkgs.symlinkJoin {
      name = "tow-boot-${config.device.identifier}-scripts";
      paths =
        let updater = mbr_disk_id:
          (pkgs.writeShellScriptBin "tow-boot-update-rpi" ''
            set -x
            set -euo pipefail

            #
            # FIND + REMOUNT FIRMWARE (pull this to common script?)
            # TODO: mount firmware by the partition-id
            sudo dd if="$self" of=/dev/disk/by-partlabel/''${mbr_disk_id}-01

            sudo mount -o remount,rw /disk/by-partlabel/TOWBOOT-FI

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
          '');
        in
        [
          (updater false)
          (updater true)
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
          target="$PWD"
                
          ## rpi boot config
          cp -v "${configTxt}" "$target/config.txt"
          
          ## rpi firmware / bootloader
          fwb="${cfg.firmwarePackage}/share/raspberrypi/boot"
          cp -vt "$target/" $fwb/bootcode.bin $fwb/fixup*.dat $fwb/start*.elf

          ## rpi4 armstubs
          cp -vt "$target/" "${rpipkgs.raspberrypi-armstubs}/armstub8-gic.bin"

          ## mainline (kernel, dtbs, !overlays)
          # TODO: use `install` instead?
          mkdir -p "$target/upstream"
          cp -vt "$target/upstream/" \
            "${config.Tow-Boot.outputs.firmware}/binaries/${final_binary}" \
            ${cfg.mainlinePackage.kernel}/dtbs/broadcom/bcm*rpi*.dtb
            
          ## foundation (kernel, dtbs, overlays)
          cp -vrt "$target/" \
            "${config.Tow-Boot.outputs.firmware}/binaries/${final_binary}" \
            ${rpipkgs.linuxPackages_rpi4.kernel}/dtbs/broadcom/bcm*rpi*.dtb \
            "${cfg.firmwarePackage}/share/raspberrypi/boot/overlays"
        '';

        # The build, since it includes misc. files from the Raspberry Pi Foundation
        # can get quite bigger, compared to other boards.
        size = 32 * 1024 * 1024;
        fat32 = {
          partitionID = cfg.partitionID;
        };
        label = "TOW-BOOT-FI";
      };
    };
  };
  # documentation.sections.installationInstructions = ''
  #   ## Installation instructions
  #   ${config.documentation.helpers.genericSharedStorageInstructionsTemplate {
  #     storage = "an SD card, USB drive (if the Raspberry Pi is configured correctly) or eMMC (for systems with eMMC)";
  #   }}
  # '';
}

