{
  system ? builtins.currentSystem
, inputs
}: 

let
  # Original `evalConfig`
  evalConfig = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix";
  # Import modules from Nixpkgs
  fromNixpkgs = map (module: "${inputs.nixpkgs}/nixos/modules/${module}");
in
rec {
  # Evaluates Tow-Boot, and the device config with the given additional modules.
  evalWith =
    { modules ? []
    , device
    , additionalConfiguration ? {}
    , system ? system
    , specialArgs ? {}
    , baseModules ? (
      [
        ../../modules
      ] ++ (fromNixpkgs [
        # (Limit this to as much as possible)
        "misc/assertions.nix"
        "misc/nixpkgs.nix"
      ])
    )
  }: evalConfig {
    inherit baseModules;
    inherit system;
    inherit specialArgs;
    modules = []
      # `device` can be a couple of types.
      ++ (   if builtins.isAttrs device then [ device ]                    # An attrset is used directly
        else if builtins.isPath device then [ { imports = [ device ]; } ]  # A path added to imports
        else [ { imports = [(../../. + "/boards/${device}")]; } ])         # A string is looked-up locally
      # Our own modules
      ++ modules
      # Any additional optional configuration this should be evaluated with.
      ++ [ additionalConfiguration ]
    ;
  };

  keepEval = (eval: eval.config.device.inRelease);

  allDevices =
    builtins.filter
    (d: builtins.pathExists (../../. + "/boards/${d}/default.nix"))
    (builtins.attrNames (builtins.readDir ../../boards))
  ;

  evals = builtins.map (device: evalWith { inherit device; }) allDevices;

  releasedDevicesEvaluations = builtins.filter keepEval evals;
}
