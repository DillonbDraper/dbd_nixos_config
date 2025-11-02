# Roy-specific Home Manager configuration
{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../home  # Import shared home-manager config from home/default.nix
  ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#roy";
  };
}

