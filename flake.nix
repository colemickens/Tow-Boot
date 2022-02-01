{
  description = "tow-boot";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    rpipkgs = { url = "github:colemickens/nixpkgs/rpipkgs"; };
  };

  outputs = inputs:
    let
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = genAttrs supportedSystems;

      allDevices =
        let
          p = d: ./. + "/boards/${d}/default.nix";
          res = builtins.filter
            (d: builtins.pathExists
              # (builtins.trace (p d) (p d))
              (p d))
            (builtins.attrNames (builtins.readDir ./boards));
        in
        # builtins.trace res res;
        res;

      # evalFor = { device, configuration, system }:
      #   import ./support/nix/eval-with-configuration.nix ({
      evalFor = { device, configuration, system }:
        let releaseTools = import ./support/nix/release-tools.nix {
          inherit system inputs;
        }; in
        releaseTools.evalWith {
          inherit device;
          inherit system;
          additionalConfiguration = configuration;
          specialArgs = { inherit inputs; };
        };

      _devicesWith = forAllSystems
        (system: genAttrs allDevices
          (d: (userConfig: evalFor
            ({
              device = d;
              system = system;
            } // userConfig))));
      _devices = forAllSystems
        (system: genAttrs allDevices
          (d: (evalFor
            {
              device = d;
              system = system;
            })));
    in
    {
      nixosModules = [
        (import ./nixos/integration.nix {inherit inputs;})
      ];

      # devices = _devices;
      devicesWith = _devicesWith;

      defaultPackage = forAllSystems
        (system:
          genAttrs allDevices
            (d: {
              name = d;
              value = _devices.${d}.${system};
            }));
    };
}
