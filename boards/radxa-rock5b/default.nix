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
    identifier = "evb-rk3588"; ##### TODO
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
    #     SPL_ENV_IS_NOWHERE = lib.mkForce yes;
    #     SPL_SPI_FLASH_SUPPORT = lib.mkForce yes;
    #     SPL_SPI_SUPPORT = lib.mkForce yes;
    #     SPL_SPLI_LOAD = lib.mkForce yes;
    #     SYS_WHITE_ON_BLACK = lib.mkForce yes;
    #     TPL_ENV_IS_NOWHERE = lib.mkForce yes;
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
          rev = "46349e27812413f73197fc3eec460743940314de";
          sha256 = "sha256-UlJp7sXHp9+zGrCJ3DOh7+VzqJrDCyeFW6czXNdhfJA=";
        };
        p2 = "$out/configs/evb-rk3588_defconfig";
        s2 = pkgs.runCommand "fix-rk3588-ubootdefconfig" { } ''
          set -x
          set -eu
          cp -r ${s1} $out
          chmod -R +w $out
          cat <<EOF >> "${p2}"
          CONFIG_NR_DRAM_BANKS=2
          CONFIG_PCI=y
          CONFIG_PCI_INIT_R=y
          CONFIG_DEBUG_UART=y
          CONFIG_ROCKCHIP_RK3588=y
          CONFIG_OF_BOARD_SETUP=y
          CONFIG_SPL_ENV_IS_NOWHERE=y
          CONFIG_TPL_ENV_IS_NOWHERE=y
          CONFIG_ROCKCHIP_GPIO=y
          CONFIG_VIDEO=y
          CONFIG_CMD_DFU=y
          CONFIG_CMD_GPIO=y
          CONFIG_CMD_GPT=y
          CONFIG_CMD_I2C=y
          CONFIG_CMD_MMC=y
          CONFIG_CMD_PCI=y
          CONFIG_CMD_USB=y
          CONFIG_CMD_ROCKUSB=y
          CONFIG_CMD_REGULATOR=y
          CONFIG_GMAC_ROCKCHIP=y
          CONFIG_SYS_I2C_ROCKCHIP=y
          CONFIG_SPL_OF_CONTROL=y
          CONFIG_OF_LIVE=y
          CONFIG_MISC=y
          CONFIG_SUPPORT_EMMC_RPMB=y
          CONFIG_MMC_DW=y
          CONFIG_MMC_DW_ROCKCHIP=y
          CONFIG_MMC_SDHCI=y
          CONFIG_MMC_SDHCI_SDMA=y
          CONFIG_MMC_SDHCI_ROCKCHIP=y
          CONFIG_SPI_FLASH_MACRONIX=y
          CONFIG_SPI_FLASH_XTX=y
          CONFIG_ETH_DESIGNWARE=y
          CONFIG_RTL8169=y
          CONFIG_GMAC_ROCKCHIP=y
          CONFIG_PCIE_DW_ROCKCHIP=y
          CONFIG_PHY_ROCKCHIP_INNO_USB2=y
          CONFIG_PHY_ROCKCHIP_NANENG_COMBOPHY=y
          CONFIG_PHY_ROCKCHIP_USBDP=y
          CONFIG_REGULATOR_PWM=y
          CONFIG_PWM_ROCKCHIP=y
          CONFIG_ROCKCHIP_SFC=y
          CONFIG_SYSRESET=y
          CONFIG_USB=y
          CONFIG_DM_ETH=y
          CONFIG_PHY_REALTEK=y
          CONFIG_DM_USB_GADGET=y
          CONFIG_DEBUG_UART_SHIFT=2
          CONFIG_SYS_NS16550_MEM32=y
          CONFIG_SPL_DM_USB_GADGET=y
          CONFIG_USB_XHCI_HCD=y
          CONFIG_USB_EHCI_HCD=y
          CONFIG_USB_EHCI_GENERIC=y
          CONFIG_USB_OHCI_HCD=y
          CONFIG_USB_OHCI_GENERIC=y
          CONFIG_USB_DWC3=y
          CONFIG_USB_DWC3_GENERIC=y
          CONFIG_SPL_USB_DWC3_GENERIC=y
          CONFIG_USB_ETHER_ASIX=y
          CONFIG_USB_ETHER_ASIX88179=y
          CONFIG_USB_HOST_ETHER=y
          CONFIG_USB_ETHER_LAN75XX=y
          CONFIG_USB_ETHER_LAN78XX=y
          CONFIG_USB_ETHER_MCS7830=y
          CONFIG_USB_ETHER_RTL8152=y
          CONFIG_USB_ETHER_SMSC95XX=y
          # CONFIG_USB_GADGET=y
          CONFIG_TARGET_ROCK5B_RK3588=y
          EOF

          echo "XXXXXXXXXXXXXXXXXXXXXXXXXX"
          cat "${p2}"
          echo "XXXXXXXXXXXXXXXXXXXXXXXXXX"
        '';
      in
      # s1;
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
        # ls -al spl/
        # # echo "((((((((((((()))))))))))))"
        # echo
        # echo
        # ls -al 
        # # echo "((((((((((((()))))))))))))"
        
        # # tools/mkimage \
        # #   -n rk3588 \
        # #   -T "rksd" \
        # #   -d "${blobs.ddrInit}:spl/u-boot-spl.bin" \
        # #   idbloader.img

        cp ${blobs.zero} $out/zero.img.gz
        cp u-boot-rockchip.bin $out/binaries/
        cp u-boot-rockchip-spi.bin $out/binaries/ || true ### TODO lazy
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
