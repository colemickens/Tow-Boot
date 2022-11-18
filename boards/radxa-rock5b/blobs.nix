{ runCommandNoCC, fetchurl, xxd }:

let
  rev = "9840e87723eef7c41235b89af8c049c1bcd3d133";
  bl31Ver = "v1.28";
  ramVer = "v1.08";
in
{
  BL31 =
    fetchurl {
      url = "https://github.com/radxa/rkbin/raw/${rev}/bin/rk35/rk3588_bl31_${bl31Ver}.elf";
      sha256 = "sha256-mCx3v6musfwuf+HKFpYfQrk5RGjx3TZ1LeRwONEZVYs=";
    };

  # Originally 60e3 16__; 0x16e360, 1500000
  # Changed to 0x1c200, 115200, 00c2 01__
  # Finding the offset: `grep '60 \?e3 \?16'`
  ram_init =
    runCommandNoCC "rk3588-patched-ram_init"
      {
        nativeBuildInputs = [
          xxd
        ];
        ram_init = fetchurl {
          url = "https://github.com/radxa/rkbin/raw/${rev}/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_${ramVer}.bin";
          sha256 = "sha256-E4olArzqDOvlgYM3kAYLIdOaZ7YD2OdjPYUFvTmt6ns=";
        };
      } ''
      cat $ram_init > $out

      # xxd -r - $out <<EOF
      # 0000e7c0: 110d 2b0d 0000 0000 1e0d 3808 00c2 0120
      # EOF
    ''
  ;
}
