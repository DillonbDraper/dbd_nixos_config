# Hardware configuration for marth
# This file should be populated with the output of nixos-generate-config
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # Add hardware-specific configuration here

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

