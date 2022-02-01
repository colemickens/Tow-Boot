{
  configuration ? { }
, silent ? false
, inputs
, system ? builtins.currentSystem
}:

let
  pkgs = import inputs.nixpkgs { inherit system; };

  release-tools = import ./support/nix/release-tools.nix { inherit inputs system; };

  inherit (release-tools)
    allDevices
  ;

  evalFor = device:
    import ./support/nix/eval-with-configuration.nix ({
      inherit device;
      inherit system;
      inherit inputs;
      verbose = true;
      configuration = {
        imports = [
          configuration
          (
            { lib, ... }:
            {
              # Special configs for imperative use only here
              system.automaticCross = true;
            }
          )
        ];
      };
    })
  ;

  outputs = builtins.listToAttrs (builtins.map (device: { name = device; value = evalFor device; }) allDevices);
  outputsCount = builtins.length (builtins.attrNames outputs);
in

outputs // {
  ___aaallIsBeingBuilt = if silent then null else (
  builtins.trace (pkgs.lib.removePrefix "trace: " ''
    trace: +--------------------------------------------------+
    trace: | Notice: ${pkgs.lib.strings.fixedWidthString 3 " " (toString outputsCount)} outputs will be built.               |
    trace: |                                                  |
    trace: | You may prefer to build a specific output using: |
    trace: |                                                  |
    trace: |   $ nix-build -A vendor-board                    |
    trace: +--------------------------------------------------+
 '') null);
}
