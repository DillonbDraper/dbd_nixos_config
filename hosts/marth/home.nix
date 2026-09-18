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
    whisper-cpp

    # nix related
    nix-output-monitor

    # torrent
    qbittorrent

    # vpn/work suite
    inputs.nixpkgs-mattermost.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mattermost-desktop

    # Terminal emulators
    alacritty
    ghostty
    foot
    vtebench

    # gaming
    runelite
    gamescope
    gamemode
    libnotify
    input-integrity-lossless
    solaar # logitech mouse software

    # Music/video players
    mpv
    deno
    mpvScripts.mpris
    mpvScripts.uosc
    mpvScripts.sponsorblock-minimal
    feishin

    # editors
    kakoune

    # extra browsers:
    brave
    google-chrome

    # TURN server
    coturn
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

  programs.retroarch.enable = true;
  programs.retroarch.cores = {
    mgba.enable = true;
    bsnes = {
      enable = true;
      package = pkgs.libretro.bsnes-hd;
    };
  };

  # Solaar only pushes its saved settings (DPI stages, gestures, scroll
  # behavior, etc.) to the device while it is running and sees the
  # connect/pairing event -- most of these settings aren't stored on the
  # receiver/mouse firmware. Run it hidden in the background persistently
  # instead of launching it on demand, so settings survive sleep/wake,
  # receiver replugs, and reboots.
  systemd.user.services.solaar = {
    Unit = {
      Description = "Solaar Logitech device manager (background, hidden window)";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide --restart-on-wake-up";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
