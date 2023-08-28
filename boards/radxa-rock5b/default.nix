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
    manufacturer = "AliRock";
    name = "H96 Max V58";
    identifier = "rk3588-h96maxv58";
    productPageURL = "https://wiki.radxa.com/Rock5/hardware/5b"; # TODO
  };

  hardware = {
    soc = "rockchip-rk3588";
    SPISize = 16 * 1024 * 1024; # 16 MiB
  };

  Tow-Boot = {
    buildUBoot = true;
    defconfig = "h96maxv58-rk3588_defconfig";

    uBootVersion = "2023.10-rc1";
    src =
      let
        s0 = pkgs.fetchFromGitHub {
          owner = "colemickens";
          repo = "u-boot";
          rev = "80bc2c23726a52fe85c275d61e184d96bed66ebc";
          hash = "sha256-r6mK11Z4DCtzHIlwiqY2WQilHrfsGdVv2bawstW2XQM=";
        };
        in s0;

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
