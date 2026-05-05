# Diagnostic capture for niri cold-boot DRM permission-denied crash.
# See: ~/.claude/plans/i-have-been-having-piped-feigenbaum.md
{ config, pkgs, lib, ... }:

let
  sessionPollScript = pkgs.writeShellScript "logind-session-poll" ''
    set -u
    out=/var/log/logind-sessions.log
    end=$(( $(date +%s) + 300 ))
    echo "=== logind session poll started at $(date -Iseconds) (boot=$(${pkgs.systemd}/bin/journalctl --list-boots | tail -1 | awk '{print $1}')) ===" >> "$out"
    while [ "$(date +%s)" -lt "$end" ]; do
      ts=$(date -Iseconds)
      sessions=$(${pkgs.systemd}/bin/loginctl list-sessions --no-legend 2>/dev/null || true)
      printf '--- %s ---\n%s\n' "$ts" "$sessions" >> "$out"
      while read -r sid _rest; do
        [ -z "$sid" ] && continue
        ${pkgs.systemd}/bin/loginctl show-session "$sid" \
          -p Id -p User -p Name -p Type -p Class -p Active -p State -p TTY -p Display -p Seat 2>/dev/null \
          | sed "s/^/  [$sid] /" >> "$out"
      done <<< "$sessions"
      sleep 1
    done
    echo "=== logind session poll exiting at $(date -Iseconds) ===" >> "$out"
  '';
in
{
  systemd.services.drm-event-capture = {
    description = "Capture DRM udev events to /var/log/drm-events.log (niri crash diagnosis)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/udevadm monitor --kernel --udev --property --subsystem-match=drm";
      StandardOutput = "append:/var/log/drm-events.log";
      StandardError = "append:/var/log/drm-events.log";
      Restart = "on-failure";
    };
  };

  systemd.services.logind-session-poll = {
    description = "Poll loginctl session state for 300s after boot (niri crash diagnosis)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-logind.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${sessionPollScript}";
      StandardError = "journal";
    };
  };
}
