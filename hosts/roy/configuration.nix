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

  users.users.dillon.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLXpDH84DYGljeR3OZaq8X8qfTVQYgecp5aH39sdnePlpB378gVN1C3XUU9YCmzohGTYLMrHlnoc6FfplKmiMez214MXRG0/WBh3xvyyXkMzo95X1tnSgsffGGW0zMvNCTrK1UMPCjtN8nlBcCw0TkzVgwl75p/WT/0uWq1NEiPMWka1GSNBELfBwXU9Em3EO6EfmQYL7PGI30VCToo0+hAIuwKDQQLrZjQYlDiGiOGty+oTEodyuReo0FAhpuDeqTKl+uDpm/x0+CIdqjgxDmzoUFr/nUclBGastSPFv1MX11UhM7Z1NUZIUfIsWJ1xALJ6WIR8najwuRI0E6qqHlecxNlaFfgmK5bMfPnDKhfBSedjHM0LDzq3CVdPaDpV5/Ds6zRcoePTp9SBirMfMQ774iUQ5Kyos+78sGIa7Bcoxv2uZbq3YDF3qBuODGyeBJ9bsXaUFoGadP69mCHnIndLkJeGy7PHXYnfEDl7dPhnfU5fSyB68UC24dmEk8krFIWZQCh+4XzNBJxNMAywzjGjg+MHZje3fhvinajyxoq1XTJr6Q7IdffK7/4S4jxlBWxONyXY8oVpGUjZcy6C2Ho1jmnV8iYnGzyUaSNloR5Eh9cSz/+Scs+xzkGY6mpJCJ8wmMQsjCsrvu64WFOkx0v2SqJBKyl+NCAXtsEHVp+Q== dillon@nixos"
  ];
  
  # Keep running when the lid is closed; the display goes dark physically.
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
    lidSwitchDocked = "ignore";
  };

  # Prevent systemd from ever suspending or hibernating this machine.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowSuspendThenHibernate = "no";
    AllowHybridSleep = "no";
  };

  # KDE Plasma enables power-profiles-daemon by default; disable it so TLP
  # can manage power without conflicting.
  services.power-profiles-daemon.enable = false;

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
