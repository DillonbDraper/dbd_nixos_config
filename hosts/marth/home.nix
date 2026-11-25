# Marth-specific Home Manager configuration
{ config, pkgs, inputs, ... }:

let
  # SDL can claim the GameCube adapter before Dolphin's native USB backend,
  # causing "Resource busy". Apply the upstream workaround to mainline only.
  dolphinMainline = pkgs.symlinkJoin {
    name = "dolphin-emu-with-gc-adapter";
    paths = [ pkgs.dolphin-emu ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/dolphin-emu \
        --set SDL_JOYSTICK_HIDAPI_GAMECUBE 0
    '';
  };

  screenshotWindow = pkgs.writeShellApplication {
    name = "umbriel-screenshot-window";
    runtimeInputs = with pkgs; [ umbriel grim jq wl-clipboard xdg-user-dirs coreutils ];
    text = ''
      # `active` is the seat's focused window, including scratchpad windows.
      # `focused` instead remembers focus separately for every workspace.
      window_id=$(umbriel windows --json | jq -er 'first(.[] | select(.active) | .id | select(length > 0))')
      pictures=$(xdg-user-dir PICTURES)
      directory="''${pictures:-$HOME/Pictures}/Screenshots"
      mkdir -p "$directory"
      screenshot=$(mktemp "$directory/Screenshot from $(date +'%Y-%m-%d %H-%M-%S')-XXXXXX.png")
      if ! grim -T "$window_id" "$screenshot"; then
        rm -f "$screenshot"
        exit 1
      fi
      wl-copy --type image/png < "$screenshot"
    '';
  };

  # nixpkgs dropped libgcrypt and libgpg-error from appimageTools' default FHS
  # env. Slippi's Dolphin AppImages bundle libgcrypt but expect the host to
  # provide libgpg-error, so without it they fail with "required libraries may
  # be missing". Add both back to every Slippi package, including the launcher,
  # because any Dolphin build the launcher downloads runs inside its sandbox.
  slippiAppimageTools = pkgs.appimageTools // {
    wrapType2 = args: pkgs.appimageTools.wrapType2 (args // {
      extraPkgs = p: (args.extraPkgs or (_: [ ])) p ++ [ p.libgcrypt p.libgpg-error ];
    });
  };
  slippiSources = pkgs.callPackage "${inputs.slippi}/_sources/generated.nix" { };
  slippiPackage = file: source:
    pkgs.callPackage "${inputs.slippi}/packages/${file}" {
      inherit source;
      appimageTools = slippiAppimageTools;
    };
in
{
  imports = [
    ../../home  # Import shared home-manager config from home/default.nix
    inputs.slippi.homeManagerModules.slippi-launcher
    inputs.rex.homeManagerModules.default
  ];

  services.rex.enable = true;
  programs.ssh.enable = true;

  home.packages = with pkgs; [
    libreoffice-fresh
    obs-studio
    livebook
    hyperfine
    openssl
    xz

    # LLM CLI Tooling
    dreamcoder
    codex
    codex-acp
    opencode
    claude-code
    whisper-cpp
    pi-coding-agent

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
    inputs.rex-rune.packages.${pkgs.stdenv.hostPlatform.system}.default

    # gaming
    runelite
    gamescope
    gamemode
    libnotify
    input-integrity-lossless
    dolphinMainline

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
    netplayPackage = slippiPackage "slippi-netplay.nix" slippiSources.netplay;
    netplayBetaPackage = slippiPackage "slippi-netplay-beta.nix" slippiSources.netplay-beta;
    playbackPackage = slippiPackage "slippi-playback.nix" slippiSources.playback;
    launcherPackage = slippiPackage "slippi-launcher.nix" slippiSources.launcher;
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

  # Keep Umbriel's packaged bindings and defaults, then layer our session
  # startup on top. Noctalia's generated colors can live in noctalia.toml.
  xdg.configFile."umbriel/config.toml".source =
    (pkgs.formats.toml { }).generate "umbriel-config.toml" {
      include = {
        files = [ "${pkgs.umbriel}/share/umbriel/config.toml" ];
        optional.files = [ "~/.config/umbriel/noctalia.toml" ];
      };
      general.autostart = [ "noctalia" ];
      # Slippi's Dolphin AppImage needs these in the compositor session.
      # Match the working Niri environment so GUI launches inherit them.
      environment = {
        APPIMAGE_EXTRACT_AND_RUN = "1";
        FUSERMOUNT_PROG = "/run/wrappers/bin/fusermount3";
      };
      # Match the refresh rate configured for this monitor in Niri.
      output."DP-1".mode = "1920x1080@144.001";
      # The implicit default scratchpad cannot launch an application on demand.
      # Keep its usual keys, but give it a name and spawn one Emacs client frame
      # when it is empty. The title distinguishes it from regular Emacs frames.
      scratchpad = [
        {
          name = "main";
          spawn_when_empty = "${config.programs.emacs.package}/bin/emacsclient --no-wait --create-frame --frame-parameters='((name . \"Umbriel Scratchpad Emacs\") (title . \"Umbriel Scratchpad Emacs\"))'";
        }
      ];
      window_rule = [
        {
          match.title = "^Umbriel Scratchpad Emacs$";
          default_scratchpad = "main";
        }
      ];
      # Match the keyboard timing in home/niri.nix.
      input.keyboard = {
        repeat_delay = 300;
        repeat_rate = 60;
      };
      # The packaged up/down actions stop at the edge of a column. Continue
      # into adjacent workspaces there, as the Niri bindings do.
      keybinds = {
        # Match Niri's screenshot chords; Umbriel delegates capture to tools.
        "Print" = {
          action = "spawn:noctalia msg screenshot-region";
          repeat = false;
        };
        "Mod+Print" = {
          action = "spawn:env QT_QPA_PLATFORM=wayland ${pkgs.flameshot}/bin/flameshot gui";
          allow_when_inhibited = true;
          repeat = false;
        };
        "Shift+Print" = {
          action = "spawn:${screenshotWindow}/bin/umbriel-screenshot-window";
          repeat = false;
        };
        "Ctrl+Print" = {
          action = "spawn:noctalia msg screenshot-fullscreen";
          repeat = false;
        };
        "Mod+Space" = "scratchpad-toggle:main";
        "Mod+Shift+Space" = "window-move-to-scratchpad:main";
        "Mod+Ctrl+Space" = "window-restore-from-scratchpad:main";
        "Mod+Tab" = "scratchpad-focus-next:main";
        "Mod+Up" = "window-focus-or-workspace-up";
        "Mod+Down" = "window-focus-or-workspace-down";
        "Mod+K" = "window-focus-or-workspace-up";
        "Mod+J" = "window-focus-or-workspace-down";
        "Mod+Shift+Up" = "window-move-or-workspace-up";
        "Mod+Shift+Down" = "window-move-or-workspace-down";
        "Mod+Shift+K" = "window-move-or-workspace-up";
        "Mod+Shift+J" = "window-move-or-workspace-down";
	"Mod+Shift+H" = "column-move-left";
        "Mod+Shift+L" = "column-move-right";
        # Match Niri's monitor chords, moving just the focused window.
        "Mod+Ctrl+Left" = "output-focus-left";
        "Mod+Ctrl+Down" = "output-focus-down";
        "Mod+Ctrl+Up" = "output-focus-up";
        "Mod+Ctrl+Right" = "output-focus-right";
        "Mod+Ctrl+H" = "output-focus-left";
        "Mod+Ctrl+J" = "output-focus-down";
        "Mod+Ctrl+K" = "output-focus-up";
        "Mod+Ctrl+L" = "output-focus-right";
        "Mod+Ctrl+Shift+Left" = "window-move-to-output-left";
        "Mod+Ctrl+Shift+Down" = "window-move-to-output-down";
        "Mod+Ctrl+Shift+Up" = "window-move-to-output-up";
        "Mod+Ctrl+Shift+Right" = "window-move-to-output-right";
        "Mod+Ctrl+Shift+H" = "window-move-to-output-left";
        "Mod+Ctrl+Shift+J" = "window-move-to-output-down";
        "Mod+Ctrl+Shift+K" = "window-move-to-output-up";
        "Mod+Ctrl+Shift+L" = "window-move-to-output-right";
      };
    };

  programs.retroarch.enable = true;
  # The Microsoft keyboard receiver's "System Control" interface is
  # classified as a joystick and grabs pad #0, so RetroArch's saved
  # joypad indices drift and the Pro Controller ends up on port 2.
  # Pin it (057e:2009) to player 1 regardless of its pad number.
  #
  # The reservation only works if every pad belongs to exactly one player:
  # RetroArch 1.22's swap logic treats an unowned pad as player 1's and
  # hands player 1 its old (empty) slot back. Its saved table drifts into
  # that state (e.g. players 1 and 4 both on pad 3), so reset it to the
  # identity mapping on every launch and let the reservation do the swap.
  programs.retroarch.settings = {
    input_player1_device_reservation_type = "1"; # preferred
    input_player1_reserved_device = "057e:2009 Pro Controller";
  } // builtins.listToAttrs (builtins.genList (i: {
    name = "input_player${toString (i + 1)}_joypad_index";
    value = toString i;
  }) 16);
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
