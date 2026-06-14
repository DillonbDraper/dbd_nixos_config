# Roy-specific configuration — always-on laptop server
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./server_config.nix
    inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/dillon/.config/sops/age/keys.txt";

  hardware.nvidia.prime = {
    sync.enable = true;

    # Enable for lesser power consumption but worse performance
    # sync.offload = true;

    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  networking.hostName = "roy";

  # SSH access for headless/remote server management
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Keep running when the lid is closed; the display goes dark physically.
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
    lidSwitchDocked = "ignore";
  };

  # Prevent systemd from ever suspending or hibernating this machine.
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
  '';

  # Battery charge limit for always-plugged-in use.
  # ThinkPad ACPI exposes charge thresholds natively; TLP writes them at boot.
  services.tlp = {
    enable = true;
    settings = {
      # Keep the performance governor the shared config expects.
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "performance";
      # Stop charging at 80%; don't resume until below 40%.
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };
}
