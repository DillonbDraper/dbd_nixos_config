# Marth-specific Home Manager configuration
{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../home  # Import shared home-manager config from home/default.nix
    inputs.slippi.homeManagerModules.slippi-launcher
  ];

  home.packages = with pkgs; [
    libreoffice-fresh
    obs-studio
    livebook
    hyperfine
    xz

    # LLM CLI Tooling
    gemini-cli
    codex
    opencode
    claude-code

    # nix related
    nix-output-monitor

    # torrent
    qbittorrent

    # vpn/work suite
    mattermost-desktop

    # Terminal emulators
    alacritty
    ghostty
    foot
    vtebench
    rio
    xfce4-terminal
    st

    # gaming
    runelite
    gamescope
    gamemode
    libnotify
    input-integrity-lossless
    dorion # alt Discord client

    # Music/video players
    mpv
    deno
    tauon
    mpvScripts.mpris
    mpvScripts.uosc
    mpvScripts.sponsorblock-minimal

    # editors
    kakoune
  ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#marth";
  };

  slippi-launcher = {
    enable = true;
    isoPath = "/home/dillon/emulation/ssbm.iso";
    launchMeleeOnPlay = false;
    useNetplayBeta = true;
  };

  programs.niri.settings.outputs = {
    "DP-1" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 144.001;
      };
      focus-at-startup = true;
    };
  };
}
