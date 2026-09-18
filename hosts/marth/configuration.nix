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

  # Replace SDDM on Marth only. The shared configuration still enables SDDM
  # for Roy, so this must override that shared value.
  services.displayManager.sddm.enable = pkgs.lib.mkForce false;
  services.displayManager.noctalia-greeter = {
    enable = true;

    settings = {
      session.default = "niri";
      user.default = "dillon";
      keyboard.layout = "us";
    };
  };

  # Installs the Logitech HID++ udev rules so Solaar (installed via
  # home-manager) can open the Unifying receiver's /dev/hidraw node,
  # which is otherwise root:root 0600.
  hardware.logitech.wireless.enable = true;

  # Allow Simba's RemoteInput to attach to the (same-user) RuneLite client
  # without needing cap_sys_ptrace on the binary. This is the declarative
  # equivalent of the upstream `setcap cap_sys_ptrace=eip` step. ptrace_scope=0
  # lets any same-uid process ptrace another (classic permissive behaviour).
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
}
