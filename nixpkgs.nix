let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  rev = lock.nodes.nixpkgs.locked.rev;
  sha256 = lock.nodes.nixpkgs.locked.narHash;
  tarball = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
in
builtins.trace "Using default Nixpkgs revision '${rev}'..." (import tarball)
