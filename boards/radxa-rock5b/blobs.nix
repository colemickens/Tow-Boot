{ runCommandNoCC, fetchurl, xxd }:

let
  rev = "38ab40ee2b3cc3d5a4a4f9aee56cba37392ccc9e";
  bl31Ver = "v1.38";
  ddrVer = "v1.11";
in
{
  zero = fetchurl {
    url = "https://dl.radxa.com/rock5/sw/images/others/zero.img.gz";
    hash = "sha256-RLUPLPZjaL8xCPpfHU2tkBr/Sv3dPZ7bkxmCN8K7ODo=";
  };

  bl31 = fetchurl {
    url = "https://github.com/radxa/rkbin/raw/${rev}/bin/rk35/rk3588_bl31_${bl31Ver}.elf";
    hash = "sha256-UYSMxk4S4P6Coj5DtGKLW1gFtOxomyYPJ/tAnTDTsws=";
  };

  # Originally 60e3 16__; 0x16e360, 1500000
  # Changed to 0x1c200, 115200, 00c2 01__
  # Finding the offset: `grep '60 \?e3 \?16'`
  ddrInit = runCommandNoCC "rk3588-patched-ram_init"
    {
      nativeBuildInputs = [
        xxd
      ];
      ram_init = fetchurl {
        url = "https://github.com/radxa/rkbin/raw/${rev}/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_${ddrVer}.bin";
        hash = "sha256-YaRLD1NFHSKMswxjMPWPz1tTGtmQDkE/o9xldHIRvB4=";
      };
    } ''
    cat $ram_init > $out

    # xxd -r - $out <<EOF
    # 0000e7c0: 110d 2b0d 0000 0000 1e0d 3808 00c2 0120
    # EOF
  ''
  ;
}
