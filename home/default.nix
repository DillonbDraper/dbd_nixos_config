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

  # ALSA configuration for PipeWire
  home.file.".asoundrc".text = ''
    pcm.!default {
      type pulse
      fallback "sysdefault"
      hint {
        show on
        description "Default ALSA Output (via PulseAudio/PipeWire)"
      }
    }
    ctl.!default {
      type pulse
      fallback "sysdefault"
    }
  '';

  # WirePlumber configuration to set device priorities
  # Built-in audio has high priority, but Bluetooth can override when connected
  xdg.configFile."wireplumber/main.lua.d/51-default-device.lua".text = ''
    -- Built-in audio gets priority, but not so high that Bluetooth can't override
    alsa_rule = {
      matches = {
        {
          { "node.name", "equals", "alsa_output.pci-0000_00_1f.3.analog-stereo" },
        },
      },
      apply_properties = {
        ["node.priority"] = 900,
      },
    }
    table.insert(alsa_monitor.rules, alsa_rule)

    -- Bluetooth devices get higher priority when connected
    bluetooth_rule = {
      matches = {
        {
          { "node.name", "matches", "bluez*" },
        },
      },
      apply_properties = {
        ["node.priority"] = 1000,
      },
    }
    table.insert(bluez_monitor.rules, bluetooth_rule)
  '';

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    libreoffice-fresh

    inputs.niri.packages.${pkgs.system}.xwayland-satellite-unstable
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

    #fonts
    fira-code
    input-fonts
    cascadia-code
    monaspace
    alegreya

    # LLM CLI Tooling
    gemini-cli
    aider-chat-full
    cursor-cli
    cursor-agent-acp-npm

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
    usbutils # list connected USB devices
    lshw # hardware information
    wlr-randr # display information

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # torrent
    qbittorrent

    # vpn/work suite
    tailscale
    mattermost-desktop

    # Terminal emulators
    alacritty
    rio
    kitty
    ghostty

    # Launcher
    fuzzel

    # gaming
    runelite
    lutris
    gamescope
    gamemode
    libnotify
    input-integrity-lossless

    # db introspection
    jetbrains.datagrip
    dbeaver-bin

    # Build tools for expert elixir LSP
    just
    zig

    # secrets-management
    sops
  ];

  services.tailscale-systray.enable = true;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
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
      user = {
        name = "Dillon Draper";
        email = "dillonbdraper@gmail.com";
      };
      pull.rebase = true;
      core.editor = "zeditor --wait";
      init.defaultBranch = "main";
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
    initContent =
  ''
  export PATH="$PATH":"$HOME/.emacs.d/bin"
  export OBAN_KEY_FINGERPRINT="SHA256:4/OSKi0NRF91QVVXlGAhb/BIMLnK8NHcx/EWs+aIWPc"
  export OBAN_LICENSE_KEY="qnrrk2muvxyq4zxueuwdbzqdpflb453n"
  '';
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

      config.enable_wayland = false;
      config.color_scheme = 'Eldritch'
      config.font = wezterm.font 'JetBrains Mono'
      config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 };

      config.keys = {
        {
          key = 'w';
          mods = 'CTRL|SHIFT';
          action = wezterm.action.CloseCurrentPane { confirm = false };
        },
        {
          key = 'RightArrow',
          mods = 'LEADER|CTRL',
          action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
        },
        {
          key = 'DownArrow',
          mods = 'LEADER|CTRL',
          action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
        }
      };

       return config
    '';
  };

  slippi-launcher = {
    enable = true;
    isoPath = "/home/dillon/emulation/ssbm.iso";
    launchMeleeOnPlay = false;
    useNetplayBeta = true;
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
