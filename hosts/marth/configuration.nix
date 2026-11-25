# Marth-specific configuration
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./diag.nix
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
 networking.hosts = {
   "192.168.1.54" = [
     "turn.whatgrabsme.org"
     "turn.whatgrabsme.org."
   ];
 };

  # Replace SDDM on Marth only. The shared configuration still enables SDDM
  # for Roy, so this must override that shared value.
  services.displayManager.sddm.enable = pkgs.lib.mkForce false;
  services.displayManager.noctalia-greeter = {
    enable = true;

    passwordlessSyncUsers = ["dillon"];
    settings = {
      session.default = "niri";
      user.default = "dillon";
      keyboard.layout = "us";
    };
  };

  # Add Umbriel as another greeter session while keeping Niri as the default.
  # The nixpkgs module also registers Umbriel's screencast portal.
  programs.umbriel.enable = true;

  # Local container builds and smoke tests on Marth.
  virtualisation.docker.enable = true;

  # Docker socket access is effectively root-equivalent.
  users.users.dillon.extraGroups = [ "docker" ];

  # Installs the Logitech HID++ udev rules so Solaar (installed via
  # home-manager) can open the Unifying receiver's /dev/hidraw node,
  # which is otherwise root:root 0600.
  hardware.logitech.wireless.enable = true;
}
