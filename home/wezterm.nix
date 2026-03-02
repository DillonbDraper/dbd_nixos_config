{ ... }:

{
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = ''
      local config = {}
      config.enable_wayland = false

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

  xdg.configFile."wezterm/fos_bjj_session.lua".text = ''
    -- FOS-BJJ WezTerm session launcher
    -- Usage: wezterm --config-file ~/.config/wezterm/fos_bjj_session.lua start

    local wezterm = require 'wezterm'
    local mux = wezterm.mux

    wezterm.on('gui-startup', function()
      local fos_bjj = wezterm.home_dir .. '/fos_bjj'

      -- Tab 1: OSSBJJ — stop any running DB, start it, wait until ready, then launch Phoenix
      local tab, _, window = mux.spawn_window {
        cwd = fos_bjj,
        args = {
          'direnv', 'exec', fos_bjj,
          'zsh', '-ic',
          'dbstop; dbstart; echo "Waiting for DB..."; until pg_isready -q; do sleep 0.5; done; echo "DB ready."; iex -S mix phx.server; exec zsh',
        },
      }
      tab:set_title 'OSSBJJ'

      -- Tab 2: OpenCode — wait for Phoenix HTTP endpoint so Tidewave MCP can connect
      local opencode_tab, _ = window:spawn_tab {
        cwd = fos_bjj,
        args = {
          'zsh', '-ic',
          'echo "Waiting for Phoenix server..."; until curl -sf http://localhost:4000 > /dev/null; do sleep 1; done; echo "Phoenix ready."; opencode; exec zsh',
        },
      }
      opencode_tab:set_title 'OpenCode'

      -- Tab 3: Generic scratchpad terminal
      local scratch_tab, _ = window:spawn_tab {
        cwd = fos_bjj,
        args = { 'zsh' },
      }
      scratch_tab:set_title 'Scratch Term'

      tab:activate()
    end)

    return dofile(wezterm.config_dir .. '/wezterm.lua')
  '';

  xdg.configFile."wezterm/member_doc_session.lua".text = ''
    -- Member Doc WezTerm session launcher
    -- Usage: wezterm --config-file ~/.config/wezterm/member_doc_session.lua start

    local wezterm = require 'wezterm'
    local mux = wezterm.mux

    wezterm.on('gui-startup', function()
      local member_doc = wezterm.home_dir .. '/member-doc'

      -- Tab 1: Member Doc — stop any running DB, start it, wait until ready, then launch Phoenix
      local tab, _, window = mux.spawn_window {
        cwd = member_doc,
        args = {
          'direnv', 'exec', member_doc,
          'zsh', '-ic',
          'dbstop; dbstart; echo "Waiting for DB..."; until pg_isready -q; do sleep 0.5; done; echo "DB ready."; iex -S mix phx.server; exec zsh',
        },
      }
      tab:set_title 'Member Doc'

      -- Tab 2: React client
      local client_tab, _ = window:spawn_tab {
        cwd = member_doc .. '/client',
        args = {
          'direnv', 'exec', member_doc,
          'zsh', '-ic',
          'npm run local; exec zsh',
        },
      }
      client_tab:set_title 'Client'

      -- Tab 3: Claude Code — wait for Phoenix HTTP endpoint so MCPs can connect
      local claude_tab, _ = window:spawn_tab {
        cwd = member_doc,
        args = {
          'zsh', '-ic',
          'echo "Waiting for Phoenix server..."; until curl -sf http://localhost:4000 > /dev/null; do sleep 1; done; echo "Phoenix ready."; claude; exec zsh',
        },
      }
      claude_tab:set_title 'Claude'

      -- Tab 4: Generic scratchpad terminal
      local scratch_tab, _ = window:spawn_tab {
        cwd = member_doc,
        args = { 'zsh' },
      }
      scratch_tab:set_title 'Scratch Term'

      tab:activate()
    end)

    return dofile(wezterm.config_dir .. '/wezterm.lua')
  '';
}
