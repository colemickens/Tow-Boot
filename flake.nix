{
  description = "tow-boot";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
  };

  outputs = inputs:
    let
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "riscv64-linux" ];
      forAllSystems = genAttrs supportedSystems;

      evalConfig = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix";

      allDevices = builtins.filter
        (d: builtins.pathExists (../../. + "/boards/${d}/default.nix"))
        (builtins.attrNames (builtins.readDir ../../boards));

      # keepEval = (eval: eval.config.device.inRelease);
      # evals = builtins.map (device: evalWith { inherit device; }) allDevices;
      # releasedDevices = builtins.filter keepEval evals;

      evalTowBoot = { device, config, system }:
        (evalConfig {
          baseModules = [
            ./modules
            "${inputs.nixpkgs}/nixos/modules/misc/assertions.nix"
            "${inputs.nixpkgs}/nixos/modules/misc/nixpkgs.nix" ##???
            (./. + "/boards/${device}/default.nix")
          ];
          inherit system;
          modules = [
            { inherit config; }
            { system.automaticCross = true; }
          ];
          specialArgs = { inherit inputs; };
        });
    in
    rec {
      nixosModules = [
        (import ./nixos/integration.nix { inherit evalTowBoot; })
      ];
    };
}
