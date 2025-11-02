{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.twilight
    inputs.slippi.homeManagerModules.slippi-launcher
    inputs.niri.homeModules.niri
    ./niri.nix
    ./starship.nix
  ];

  home.username = "dillon";
  home.homeDirectory = "/home/dillon";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    fastfetch

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor

    # misc
    file
    which

    # nix related
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal
    zoom-us # video conferencing

    btop  # replacement of htop/nmon
    iftop # network monitoring
    lshw # hardware information

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # torrent
    qbittorrent

    # vpn/work suite
    tailscale
    mattermost-desktop

    # Niri defaults
    alacritty
    fuzzel

    # gaming
    runelite
    lutris
    input-integrity-lossless

    # db introspection
    jetbrains.datagrip
  ];

  services.tailscale-systray.enable = true;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zen-browser.enable = true;
  programs.zen-browser.policies = {
    AutofillAddressEnabled = true;
    AutofillCreditCardEnabled = false;
    DisableAppUpdate = true;
    DisableFeedbackCommands = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableTelemetry = true;
    DontCheckDefaultBrowser = true;
    NoDefaultBookmarks = true;
    OfferToSaveLogins = false;
    EnableTrackingProtection = {
      Value = true;
      Locked = true;
      Cryptomining = true;
      Fingerprinting = true;
    };
  };

  # basic configuration of git
  programs.git = {
    enable = true;
    ignores = [ ".envrc" ".direnv"];
    settings = {
      user.email = "dillonbdraper@gmail.com";
      user.name = "Dillon Draper";
      extraConfig = {
        pull.rebase = true;
        core.editor = "zeditor --wait";
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "starship"
      ];
    };
    shellAliases = {
      ll = "ls -l";
      ga = "git add --all";
      gs = "git status";
      gcm = "git commit -m";
      gpo = "git push origin";
      glo = "git pull origin";
      gb = "git checkout -b";
      # cursor and slippi-launcher are used to open the code editor and slippi launcher in a way that is compatible with Wayland
      cursor="cursor --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations";
      slippi-launcher="slippi-launcher --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations";
    };

    history.size = 10000;
  };

  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = ''
      local config = {}

      config.color_scheme = 'Eldritch'
      config.font = wezterm.font 'JetBrains Mono'

       return config
    '';
  };

  slippi-launcher = {
    enable = true;
    isoPath = "/home/dillon/dolphin_games/ssbm.iso";
    launchMeleeOnPlay = false;
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}

