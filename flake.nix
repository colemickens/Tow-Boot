{
  description = "tow-boot";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    rpipkgs = { url = "github:colemickens/nixpkgs/rpi-updates-auto"; };
  };

  outputs = inputs:
    let
      defaultOutputs = curSystem:
        import ./default.nix {
          inputs = inputs;
          system = curSystem;
        };
      
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = genAttrs supportedSystems;
      output = forAllSystems (system: (defaultOutputs system));
    in output;
}
