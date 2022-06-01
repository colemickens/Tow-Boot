{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.Tow-Boot.rpi;

  rpipkgs = import inputs.rpipkgs {
    system = pkgs.system; # TODO: ?
  };

  final_binary = "Tow-Boot.noenv.rpi_arm64.bin";
  configTxt =
    let
      toBooint = (v: if v then "1" else "0");
      toStr = (v: toString v);
      toIntint = (v: toString v);
      opt = (f: p:
        let chk =
          if (builtins.hasAttr p cfg && cfg."${p}" != null)
          then (f cfg."${p}")
          else null;
        in
        (lib.optionalString (chk != null) ''
          ${p}=${chk}   # Tow-Boot.config.rpi.${p}
        '')
      );
      # TODO: pretty sure pi3- prefix isn't needed
      # these aren't doing shit on either pi4 or pi3b with mainline
      # (even with kernel generation DTB off)
      configTxtPi3 = (''
        # gpu_mem=512                # Tow-Boot.config.rpi.enable_vc4_kms # TODO
      '');
      configTxtPi02 = (''
        # gpu_mem=128                # Tow-Boot.config.rpi.enable_vc4_kms # TODO
      '');
      configTxtPi4 = (''
        enable_gic=1
        armstub=armstub8-gic.bin
      '') + (lib.optionalString (cfg.enable_vc4_kms && !cfg.upstream_kernel) ''
        # gpu_mem=256                # Tow-Boot.config.rpi.enable_vc4_kms
      '') + (lib.optionalString (cfg.enable_vc4_kms && cfg.upstream_kernel) ''
        # gpu_mem=256                # Tow-Boot.config.rpi.enable_vc4_kms
      '')
      + (lib.optionalString ((cfg.hdmi_enable_4kp60 != null) && cfg.hdmi_enable_4kp60) ''
          hdmi_enable_4kp60=1
          # core_freq=600 # untested
          # core_freq_min=600 # untested
      '')
      ;
    in
    pkgs.writeText "config.txt"
      (''
        # TowBoot summary:
        # firmwarePackage: ${cfg.firmwarePackage.name}
        # foundationKernel: ${cfg.foundationKernel.name}
        # mainlineKernel: ${cfg.mainlineKernel.name}
        # eepromPackage: ${cfg.eepromPackage.name}
        # armstubsPackage: ${cfg.armstubsPackage.name}
      
        [all]
        arm_64bit=1
        enable_uart=1
        avoid_warnings=1
        upstream_kernel=${toBooint cfg.upstream_kernel}
        kernel=${final_binary}
      ''
      + (opt toBooint "arm_boost")
      + (opt toIntint "initial_boost")
      + (opt toBooint "force_turbo")
      + (opt toBooint "uart_2ndstage")
      + (opt toBooint "hdmi_safe")
      + (opt toBooint "hdmi_force_hotplug")
      + (opt toStr "hdmi_drive")
      + (opt toBooint "hdmi_ignore_cec")
      + (opt toBooint "hdmi_ignore_cec_init")
      + (opt toBooint "disable_overscan")
      + (opt toBooint "disable_fw_kms_setup")
      + (lib.optionalString (cfg.enable_watchdog != null && cfg.enable_watchdog) ''
          dtparam=watchdog=on
        '')
      + (lib.optionalString (cfg.upstream_kernel != null && !cfg.upstream_kernel) ''
          os_prefix=foundation/
        '')
      + ''

        [pi4]
        ${configTxtPi4}
        [pi3]
        ${configTxtPi3}
        [pi02]
        ${configTxtPi02}
      '');

  # BOOT_ORDER: (pi reads the hex value RTL (LSB->MSB))
  # 0x0 = SD-CARD-DETECT
  # 0x1 = SD-CARD
  # 0x2 = NETWORK
  # 0x3 = RPIBOOT
  # 0x4 = USB-MSD
  # 0x_ = BCM-USB-MSD
  # 0x_ = NVME
  # 0x_ = STOP
  # 0xf = RESTART
  bootconfTxt = pkgs.writeText "bootconf.txt" ''
    [all]
    BOOT_UART=1
    ENABLE_SELF_UPDATE=1
    # BOOT_ORDER=0xf2146 # NVME => USB-MSB => SD-CARD => NETWORK => RESTART
    BOOT_ORDER=0xf241 # SD-CARD => USB-MSD => NETWORK => RESTART
  '';
  eepromBin = pkgs.runCommandNoCC "pieeprom.bin" { } ''
    set -x
    set -euo pipefail

    dir="${cfg.eepromPackage}/share/rpi-eeprom/stable"
    orig="$(ls $dir | grep pieeprom | sort | tail -1)"

    ${cfg.eepromPackage}/bin/rpi-eeprom-config \
      --config "${bootconfTxt}" \
      --out $out \
        "$(readlink -f $dir/$orig)"
  '';

  firmwareContents = pkgs.runCommandNoCC "firmware-contents" { } ''
    mkdir $out
    target="$out"

    ## rpi boot config
    # We assume that a user is customizing config.txt via a custom tow-boot build
    cp -v "${configTxt}" "$target/config.txt"
         
    ## rpi firmware / bootloader
    fwb="${cfg.firmwarePackage}/share/raspberrypi/boot"
    cp -vt "$target/" $fwb/bootcode.bin $fwb/fixup*.dat $fwb/start*.elf

    ## rpi firmware DTBs

    ## rpi4 armstubs
    cp -vt "$target/" "${cfg.armstubsPackage}/armstub8-gic.bin"

    ## mainline (kernel, dtbs, !overlays)
    mkdir -p "$target/upstream"
    cp -vt "$target/upstream/" \
      "${config.Tow-Boot.outputs.firmware}/binaries/${final_binary}" \
      ${cfg.mainlineKernel}/dtbs/broadcom/bcm*rpi*.dtb
            
    ## foundation (kernel, dtbs, overlays)
    mkdir -p "$target/foundation"
    cp -vrt "$target/foundation" \
      "${config.Tow-Boot.outputs.firmware}/binaries/${final_binary}" \
      "${cfg.firmwarePackage}/share/raspberrypi/boot/overlays" \
      $fwb/*.dtb
    
    # we don't actually need this since the FW distributes DTBs:
    #  ''${cfg.foundationKernel}/dtbs/broadcom/bcm*rpi*.dtb \
  '';
  populateCommands = ''
    ${pkgs.rsync}/bin/rsync --info=progress2 --checksum -v -r --delete "${firmwareContents}/" "$target/"
  '';
  mbr_disk_id = config.Tow-Boot.diskImage.mbr.diskID;
in
{
  options = {
    Tow-Boot.rpi = {
      # configtxt options
      upstream_kernel = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
      };
      uart_2ndstage = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
      };
      hdmi_force_hotplug = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      hdmi_drive = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      hdmi_safe = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      force_turbo = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      hdmi_ignore_cec = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
      };
      hdmi_ignore_cec_init = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
      };
      disable_overscan = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      disable_fw_kms_setup = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      arm_boost = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      initial_boost = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      hdmi_enable_4kp60 = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      # custom
      enable_vc4_kms = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
      };
      enable_watchdog = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      disable_bluetooth = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
      };
      disable_wifi = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
      };
      # package overrides
      firmwarePackage = lib.mkOption {
        type = lib.types.package;
        default = rpipkgs.raspberrypifw;
      };
      eepromPackage = lib.mkOption {
        type = lib.types.package;
        default = rpipkgs.raspberrypi-eeprom;
      };
      armstubsPackage = lib.mkOption {
        type = lib.types.package;
        default = rpipkgs.raspberrypi-armstubs;
      };
      mainlineKernel = lib.mkOption {
        type = lib.types.package;
        default = rpipkgs.linuxPackages_latest.kernel;
      };
      foundationKernel = lib.mkOption {
        type = lib.types.package;
        default = rpipkgs.linuxPackages_rpi4.kernel;
      };
    };
  };

  config = {
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

    Tow-Boot = (
      {
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
        outputs.scripts = {
          # TODO: yeesh. commit to findmnt or require /boot/firmware to
          # be the mntpt? maybe we confirm the findmnt is right
          # then we remount it. if its in wrong place or wrong part, the user
          # must intervene.
          updateFirmware = pkgs.writeShellScriptBin "tow-boot-update" ''
            set -x
            set -euo pipefail

            firmpart="/dev/disk/by-partuuid/${mbr_disk_id}-01"
            target="/boot/firmware"
            [[ -d "$target" ]] || mkdir "$target" # no -p because we assume separate boot
              
            if [[ "$target" !=  "$(findmnt "$firmpart" -no "target")" ]];
            then
              printf "tow-boot-update:: the expected /boot/firmware isn't mounted!\n" \
                >/dev/stderr
              exit 0
            fi

            function cleanup() {
              mount -o remount,ro "$firmpart"
            }
        
            mount -o remount,rw "$firmpart"
            trap cleanup EXIT
              
            ${populateCommands}

            echo "all done"
          '';
          updateEeprom = pkgs.writeShellScriptBin "tow-boot-rpi-eeprom-update" ''
            #
            # UPDATE EEPROM
            sudo ${cfg.eepromPackage}/bin/rpi-eeprom-update -r || true
            sudo env BOOTFS=/boot/firmware \
              ${cfg.eepromPackage}/bin/rpi-eeprom-update \
                -d -f "${eepromBin}"
          '';
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
        # not sure what this is even for? What is using the "$out/binaries/NAME" as an API? Why is this configurable?
        # esp since this already relies on the internals of the builder for 'u-boot.bin' file ?
        # if anything, I feel like the builder should just take a "destination" and it knows how to place it
        builder.installPhase = ''
          cp -v u-boot.bin $out/binaries/${final_binary}
        '';

        # TODO: why is there "outputs.firmware", "installerPhase" AND "populateCommands"... ?


        # TODO: this option name is confusing given the lines below it literally
        # "write" the binary into the firmware part (but I suspect "write" vs "copy" is the key)
        # The Raspberry Pi firmware expects a filesystem to be used.
        writeBinaryToFirmwarePartition = false;

        diskImage = {
          partitioningScheme = "mbr"; # rpi3b rom supposedly only supports MBR
        };
        firmwarePartition = {
          partitionType = "0C";
          filesystem = {
            filesystem = "fat32";
            populateCommands = ''
              target=$(pwd)
              ${populateCommands}
            '';

            # The build, since it includes misc. files from the Raspberry Pi Foundation
            # can get quite bigger, compared to other boards.
            size = 32 * 1024 * 1024;
            fat32 = {
              partitionID = mbr_disk_id;
            };
            label = "TOW-BOOT-FI";
          };
        };
      }
    );
    # documentation.sections.installationInstructions = ''
    #   ## Installation instructions
    #   ${config.documentation.helpers.genericSharedStorageInstructionsTemplate {
    #     storage = "an SD card, USB drive (if the Raspberry Pi is configured correctly) or eMMC (for systems with eMMC)";
    #   }}
    # '';
  };
}

