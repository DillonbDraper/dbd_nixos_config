# Roy-specific configuration
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  hardware.nvidia.prime = {
  sync.enable = true;

  # Enable for lesser power consumption but worse performance
  # sync.offload = true;

    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };


  networking.hostName = "roy";
}

