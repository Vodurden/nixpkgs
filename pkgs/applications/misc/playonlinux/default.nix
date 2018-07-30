{ pkgs, newScope, stdenv }:
let
  callPackage = newScope self;

  self = rec {
    playonlinux = callPackage ./playonlinux.nix { stdenv = stdenv; };
    playonlinux-chrootenv = callPackage ./chrootenv.nix { };
  };
in self
