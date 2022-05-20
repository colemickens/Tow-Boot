{
  description = "tow-boot";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    rpipkgs = { url = "github:colemickens/nixpkgs/rpipkgs"; };
  };

  outputs = inputs:
    let
      defaultOutputs = curSystem:
        import ./default.nix {
          inputs = inputs;
          system = curSystem;
        };

      nixosModules = [
        ./nixos/integration.nix
      ];
      
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = genAttrs supportedSystems;
      output = forAllSystems (system: (defaultOutputs system));
    in output // {
      nixosModules = nixosModules;
    };
}
