

{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.zen-browser.homeModules.twilight
    inputs.niri.homeModules.niri
    ./niri.nix
    ./starship.nix
    ./wezterm.nix
    ./kitty.nix
  ];

  home.username = "dillon";
  home.homeDirectory = "/home/dillon";

  systemd.user.startServices = "sd-switch";

  programs.emacs = {                  
    enable = true;      
    package = pkgs.emacs-pgtk;
  };
  
  services.emacs = {                  
    enable = true;
    
    # Start when your graphical user session starts. 
    startWithUserSession = "graphical";
    
    # Generate an "Emacs Client" desktop entry.                      
    client = {                
      enable = true;         
      arguments = [ "-c" ];
    };
    # Sets EDITOR/VISUAL to an emacsclient wrapper
    defaultEditor = true;
  };

  # The daemon otherwise inherits TERM="" and every magit commit dies with
  # "there was a problem with the editor".  niri-session re-execs through a
  # login zsh, where /etc/set-environment's `export TERM=$TERM` turns an unset
  # TERM into an exported empty string (zsh, unlike bash, does not default it
  # to "dumb"), and then runs `systemctl --user import-environment` with no
  # argument list, so TERM="" lands in the systemd user manager.  With an empty
  # TERM emacsclient sends "-tty <pts> <empty>"; `server-process-filter' splits
  # the request with omit-nulls, so "-file" is eaten as the terminal type and
  # the leftover COMMIT_EDITMSG path is rejected as "Unknown command".
  systemd.user.services.emacs.Service.Environment = [ "TERM=dumb" ];


  
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/dillon/.config/sops/age/keys.txt";

    secrets = {
      ossbjj-google-client-secret = { };
      ossbjj-google-client-id = { };
      ossbjj-google-redirect-uri = { };
      oban-key-fingerprint = { };
      oban-license-key = { };
    };
  };

  # ALSA configuration for PipeWire.
  # Keep ALSA-only applications on PipeWire instead of falling back to raw
  # hardware devices, which can make apps like RuneLite grab the USB DAC
  # exclusively and prevent PipeWire from seeing/using it.
  home.file.".asoundrc".text = ''
    pcm.!default {
      type pipewire
      playback_node "-1"
      capture_node "-1"
      hint {
        show on
        description "Default ALSA Output (via PipeWire)"
      }
    }
    ctl.!default {
      type pipewire
    }
  '';


  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    docker

    inputs.niri.packages.${pkgs.system}.xwayland-satellite-unstable
    (pkgs.lib.hiPrio pkgs.expert-lsp)
    fastfetch

    # archives
    zip
    unzip
    p7zip

    # utils
    ripgrep # Faster grep
    fzf # Fuzzy find
    devicon-lookup # Icon utility for commands
    yazi # File explorer
    lf # File explorer
    grc # colorizer for other commands
    bat # cat clone with extra goodies
    jq # A lightweight and flexible command-line JSON processor
    cloc # code loc/types of code checker
    difftastic # syntax aware diff tool

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
    # codex-acp 
    pi-coding-agent-custom

    # nix related
    # it provides the command `nom` works just like `nix`
    # with more details log output

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal
    zoom-us # video conferencing
    pandoc # Document conversion/processing

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

    # vpn/work suite
    tailscale
    proton-vpn

    # Terminal emulators
    kitty
    
    # Launcher
    fuzzel

    # gaming

    # db introspection
    jetbrains.datagrip
    dbeaver-bin

    # Build tools for expert elixir LSP
    just
    zig

    # secrets-management
    sops

    # Music players
    quodlibet

    # editors
    zed-editor-fhs
    neovim
    helix

    # Emacs pkgs
    elixir-ls
     (aspellWithDicts (dicts: with dicts; [
      fr
      en
      en-computers
      en-science
    ]))
    (pkgs.emacsPackages.treesit-grammars.with-grammars (p: with p; [
      tree-sitter-bash
      tree-sitter-css
      tree-sitter-elixir
      tree-sitter-heex
      tree-sitter-html
      tree-sitter-javascript
      tree-sitter-json
      tree-sitter-markdown
      tree-sitter-python
      tree-sitter-sql
      tree-sitter-toml
      tree-sitter-tsx
      tree-sitter-typescript
      tree-sitter-yaml
      tree-sitter-nix
    ]))
    emacs-lsp-booster
    typescript-language-server
    marksman
    basedpyright
    typescript
    nil
    tree-sitter

    #FOSS slsk client
    nicotine-plus

    # Youtube downloader
    yt-dlp

    # Screenshots
    slurp
    wl-clipboard
  ];

  services.tailscale-systray.enable = true;
  services.flameshot = {
  enable = true;
  settings = {
    General = {
      useGrimAdapter = true;
      disabledGrimWarning = true;
    };
   };
  };

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
      github = {
        user = "DillonbDraper";
      };
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
  export PATH=/home/dillon/.local/bin:$PATH
  export PATH="$PATH":"$HOME/.emacs.d/bin"

  export GOOGLE_CLOUD_PROJECT="best-gemini-api"
  export VERTEX_LOCATION="global"
  export GOOGLE_APPLICATION_CREDENTIALS=/home/dillon/best-gemini-api.json
  export OSSBJJ_GOOGLE_CLIENT_SECRET="$(<"${config.sops.secrets.ossbjj-google-client-secret.path}")"
  export OSSBJJ_GOOGLE_CLIENT_ID="$(<"${config.sops.secrets.ossbjj-google-client-id.path}")"
  export OSSBJJ_GOOGLE_REDIRECT_URI="$(<"${config.sops.secrets.ossbjj-google-redirect-uri.path}")"
  export OBAN_KEY_FINGERPRINT="$(<"${config.sops.secrets.oban-key-fingerprint.path}")"
  export OBAN_LICENSE_KEY="$(<"${config.sops.secrets.oban-license-key.path}")"
   
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
      launch_ossbjj="kitty --session ~/.config/kitty/sessions/fos_bjj.session";
      launch_coop="kitty --session ~/.config/kitty/sessions/member_doc.session";
    };

    history.size = 10000;
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
