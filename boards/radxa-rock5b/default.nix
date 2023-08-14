/*

  https://github.com/radxa/u-boot/tree/stable-5.10-rock5
  https://github.com/radxa/rkbin

*/
{ config, lib, pkgs, ... }:

let
  tbcfg = config.Tow-Boot;
  blobs_ = pkgs.callPackage ./blobs.nix { };
  blobs = builtins.trace "x${pkgs.path}" blobs_;
in
{
  device = {
    manufacturer = "RadxAli";
    name = "ROCK 5B";
    identifier = "radxa-rock5b";
    productPageURL = "https://wiki.radxa.com/Rock5/hardware/5b";
  };

  hardware = {
    soc = "rockchip-rk3588";
    SPISize = 16 * 1024 * 1024; # 16 MiB
  };

  Tow-Boot = {
    buildUBoot = true;
    defconfig = "evb-rk3588_defconfig";
    # config = [
    #   (helpers: with helpers; {
    #     SYS_WHITE_ON_BLACK = lib.mkForce yes;
    #     TPL_ENV_IS_NOWHERE = lib.mkForce yes;
    #     SPL_SPI_SUPPORT = lib.mkForce yes;
    #   })
    # ];

    # config = [
    #   (helpers: with helpers; {
    #     USB_GADGET_MANUFACTURER = freeform ''"Radxa"'';
    #     DISABLE_CONSOLE = lib.mkForce no;
    #     DM_ETH = yes;
    #     PHY_REALTEK = lib.mkForce yes;
    #     PHY_RK630 = yes;
    #     DEBUG_UART = lib.mkForce yes;
    #   })
    #   (helpers: with helpers; {
    #     EFI_LOADER = yes;
    #     SYS_MMCSD_RAW_MODE_U_BOOT_USE_PARTITION = no;
    #     # Offset for U-Boot proper is hardcoded in our builder
    #     # 0x80000 / 512
    #     MTD_BLK_U_BOOT_OFFS = freeform "0x400";
    #     SPL_LIBDISK_SUPPORT = no;
    #   })
    #   # Not present in this older revision
    #   (helpers: with helpers; {
    #     AUTOBOOT_MENUKEY = lib.mkForce (option no);
    #     AUTOBOOT_USE_MENUKEY = lib.mkForce (option no);
    #     CMD_CLS = lib.mkForce (option no);
    #     SYSINFO = lib.mkForce (option no);
    #     SYSINFO_SMBIOS = lib.mkForce (option no);
    #   })
    #   # Environment is not supported with the BSP build
    #   (helpers: with helpers; {
    #     ENV_IS_NOWHERE = lib.mkForce yes;
    #     ENV_ADDR = lib.mkForce no;
    #     ENV_IS_IN_SPI_FLASH = lib.mkForce no;
    #     ENV_OFFSET = lib.mkForce no;
    #     ENV_SECT_SIZE = lib.mkForce no;
    #   })
    #   (helpers: with helpers; {
    #     OPTEE_CLIENT = no;
    #     ANDROID_BOOTLOADER = yes;
    #     ANDROID_BOOT_IMAGE = yes;
    #     ANDROID_AVB = no;
    #     ANDROID_BOOT_IMAGE_HASH = no;
    #     LIBAVB = no;
    #     AVB_VERIFY = no;
    #     CMD_AVB = no;
    #     LOG = yes;
    #     LOG_CONSOLE = yes;
    #     LOG_MAX_LEVEL = freeform "7";
    #   })
    # ];

    uBootVersion = "2023.10-rc1";
    src =
      let
        s1 = pkgs.fetchFromGitLab {
          domain = "gitlab.collabora.com";
          owner = "hardware-enablement/rockchip-3588";
          repo = "u-boot";
          # https://gitlab.collabora.com/hardware-enablement/rockchip-3588/u-boot/-/commits/2023.10-rc1-rk3588/
          # 13-aug-2023
          rev = "521deb5b8e6b9492ffe73efc46997d5b30b7aaf6";
          sha256 = "sha256-42fsXKlJZ7RTfZeN4RuVGHxK0zFzxAyfzRteU4BmGb0=";
        };
        p = "$out/configs/rock5b-rk3588_defconfig";
        p2 = "$out/configs/evb-rk3588_defconfig";
        s2 = pkgs.runCommand "fix-rk3588-ubootdefconfig" { } ''
          set -x
          set -eu
          cp -r ${s1} $out
          chmod -R +w $out
          echo "CONFIG_VIDEO=y" >> "${p}"
          echo "CONFIG_VIDEO=y" >> "${p2}"
          echo "CONFIG_SPL_SPI_LOAD=y" >> "${p2}"
          echo "CONFIG_SYS_SPI_U_BOOT_OFFS=0x60000" >> "${p2}"
        '';
      in
      s2;

    # Disable features causing trouble
    withLogo = false;

    # builder.preBuild = ''
    #   substituteInPlace arch/arm/mach-rockchip/decode_bl31.py \
    #     --replace "/usr/bin/env python2" "${pkgs.buildPackages.python2}/bin/python2"
    # '';

    builder.additionalArguments = {
      BL31 = blobs.bl31;
      ROCKCHIP_TPL = blobs.ddrInit;
    };

    builder.installPhase = lib.mkMerge [
      # https://github.com/radxa/build/blob/428769f2ab689de27927af4bc8e7a9941677c366/mk-uboot.sh#L341-L347
      (lib.mkBefore ''
        # echo ':: Building specific outputs for the proprietary flavoured bits'
        # (PS4=" $ "; set -x
        # make $makeFlags "''${makeFlagsArray[@]}" spl/u-boot-spl.bin u-boot.dtb u-boot.itb
        # )
        # echo ':: Building proprietary flavoured idbloader.img'
        # echo "((((((((((((()))))))))))))"
        ls -al spl/
        # echo "((((((((((((()))))))))))))"
        echo
        echo
        ls -al 
        # echo "((((((((((((()))))))))))))"
        
        # tools/mkimage \
        #   -n rk3588 \
        #   -T "rksd" \
        #   -d "${blobs.ddrInit}:spl/u-boot-spl.bin" \
        #   idbloader.img

        cp ${blobs.zero} $out/zero.img.gz
        cp u-boot-rockchip.bin $out/binaries/
        cp u-boot-rockchip-spi.bin $out/binaries/
        cp u-boot.itb $out/binaries/
        cp idbloader.img $out/binaries/
      '')
    ];

    patches = [
      #   ./patches/0001-BACKPORT-cmd-pxe-Increase-maximum-path-length.patch
      # ./patches/0001-rk3588_common-Disable-mtd-boot-target.patch
      # ./patches/0001-part_efi-Avoid-deluge-of-print-when-device-is-not-GP.patch
    ];
  };
}
