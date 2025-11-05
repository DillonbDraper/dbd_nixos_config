# Marth-specific Home Manager configuration
{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../home  # Import shared home-manager config from home/default.nix
  ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#marth";
  };

  programs.niri.settings.outputs = {
    "DP-2" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 144.001;
      };
      focus-at-startup = true;
    };
  };
}

