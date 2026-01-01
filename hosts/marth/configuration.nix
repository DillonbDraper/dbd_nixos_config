# Marth-specific configuration
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.secrets.example-key = { };

  sops.age.keyFile = "/home/dillon/.config/sops/age/keys.txt";
#   programs.niri.package = inputs.niri.packages.${pkgs.system}.default.overrideAttrs (old: {
#   doCheck = false;
# });

 networking.hostName = "marth";
}
