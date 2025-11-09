{ config, pkgs, ... }:

{
  programs.niri.enable = true;
  
  # Keyboard repeat settings
  programs.niri.settings.input.keyboard = {
    repeat-delay = 300;  # milliseconds before key starts repeating
    repeat-rate = 60;    # characters per second when held
  };
  
  # Electron apps need to be run in a Wayland session
  programs.niri.settings.environment."NIXOS_OZONE_WL" = "1";
  # Dolphin related to fuse mounting
  programs.niri.settings.environment."FUSERMOUNT_PROG" = "/run/wrappers/bin/fusermount3";
  programs.niri.settings.environment."APPIMAGE_EXTRACT_AND_RUN" = "1";


  programs.niri.settings.spawn-at-startup = [
    {
      command = [
        "xwayland-satellite"
      ];
    }
    {
      command = [
        "noctalia-shell"
      ];
    }
  ];

  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+Space".action.spawn = "fuzzel";
    "Mod+B".action.spawn = "zen-twilight";
    "Mod+T".action.spawn = "wezterm";
    "Mod+1".action.focus-workspace = 1;
    "Mod+2".action.focus-workspace = 2;
    "Mod+3".action.focus-workspace = 3;
    "Mod+4".action.focus-workspace = 4;
    "Mod+5".action.focus-workspace = 5;
    "Mod+6".action.focus-workspace = 6;
    "Mod+7".action.focus-workspace = 7;
    "Mod+8".action.focus-workspace = 8;
    "Mod+9".action.focus-workspace = 9;
    "Mod+Shift+1".action.move-column-to-workspace = 1;
    "Mod+Shift+2".action.move-column-to-workspace = 2;
    "Mod+Shift+3".action.move-column-to-workspace = 3;
    "Mod+Shift+4".action.move-column-to-workspace = 4;
    "Mod+Shift+5".action.move-column-to-workspace = 5;
    "Mod+Shift+6".action.move-column-to-workspace = 6;
    "Mod+Shift+7".action.move-column-to-workspace = 7;
    "Mod+Shift+8".action.move-column-to-workspace = 8;
    "Mod+Shift+9".action.move-column-to-workspace = 9;
    "Mod+O".action = toggle-overview;
    "Mod+Shift+E".action = quit;
    "Mod+F".action = maximize-column;
    "Mod+Shift+F".action = fullscreen-window;
    "Mod+Q".action = close-window;
    "Mod+H".action = focus-column-left;
    "Mod+J".action = focus-window-or-workspace-down;
    "Mod+K".action = focus-window-or-workspace-up;
    "Mod+L".action = focus-column-right;
    "Mod+Left".action = focus-column-left;
    "Mod+Down".action = focus-window-or-workspace-down;
    "Mod+Up".action = focus-window-or-workspace-up;
    "Mod+Right".action = focus-column-right;
    "Mod+Ctrl+H".action = focus-monitor-left;
    "Mod+Ctrl+J".action = focus-monitor-down;
    "Mod+Ctrl+K".action = focus-monitor-up;
    "Mod+Ctrl+L".action = focus-monitor-right;
    "Mod+Ctrl+Left".action = focus-monitor-left;
    "Mod+Ctrl+Down".action = focus-monitor-down;
    "Mod+Ctrl+Up".action = focus-monitor-up;
    "Mod+Ctrl+Right".action = focus-monitor-right;
    "Mod+Shift+H".action = move-column-left;
    "Mod+Shift+J".action = move-window-down-or-to-workspace-down;
    "Mod+Shift+K".action = move-window-up-or-to-workspace-up;
    "Mod+Shift+L".action = move-column-right;
    "Mod+Shift+Left".action = move-column-left;
    "Mod+Shift+Down".action = move-window-down-or-to-workspace-down;
    "Mod+Shift+Up".action = move-window-up-or-to-workspace-up;
    "Mod+Shift+Right".action = move-column-right;
    "Mod+Ctrl+Shift+H".action = move-column-to-monitor-left;
    "Mod+Ctrl+Shift+J".action = move-column-to-monitor-down;
    "Mod+Ctrl+Shift+K".action = move-column-to-monitor-up;
    "Mod+Ctrl+Shift+L".action = move-column-to-monitor-right;
    "Mod+Ctrl+Shift+Left".action = move-column-to-monitor-left;
    "Mod+Ctrl+Shift+Down".action = move-column-to-monitor-down;
    "Mod+Ctrl+Shift+Up".action = move-column-to-monitor-up;
    "Mod+Ctrl+Shift+Right".action = move-column-to-monitor-right;

    "Mod+V".action = toggle-window-floating;
    
    "Print".action.screenshot = [ ];
    "Shift+Print".action.screenshot-window = [ ];
    "Ctrl+Print".action.screenshot-screen = [ ];
    # Show keybindings help
    "Mod+Shift+Slash".action = show-hotkey-overlay;
  };


}

