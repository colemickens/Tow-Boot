{
  description = "tow-boot";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
  };

  outputs = inputs:
    let
      defaultOutputs = curSystem: import ./default.nix {
        pkgs = (import inputs.nixpkgs {
          system = curSystem;
        });
      };

      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = genAttrs supportedSystems;
    in {
      packages = forAllSystems (system: (defaultOutputs system));
    };
}
