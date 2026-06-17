# Media-server stack for Roy (always-on laptop server).
# Ported from hosts/marth/server_config.nix.
# Before first `nixos-rebuild switch`, set serverLanIp to Roy's reserved LAN address.
{ config, lib, pkgs, ... }:

let
  mediaRoot = "/svr/newDrive";

  # Roy's reserved DHCP/static LAN address. Change this before building.
  serverLanIp = "192.168.1.54";
  lanDomain = "home.arpa";
  lanHost = name: "${name}.${lanDomain}";

  # Caddy snippets for LAN-only admin/front-end routes. DNS is only local, but
  # Caddy still listens on public 80/443, so explicitly reject non-LAN/Tailnet
  # clients that send these Host headers to the public IP.
  localOnlyReverseProxy = upstream: ''
    @allowed remote_ip 127.0.0.1/32 ::1 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 100.64.0.0/10 fd00::/8
    handle @allowed {
      reverse_proxy ${upstream}
    }
    respond 403
  '';

  # Proton WireGuard settings for routing only rTorrent through the VPN.
  # Roy needs its own WireGuard config from ProtonVPN (device-specific keypair).
  # 1. Generate a new WireGuard config in the ProtonVPN dashboard for Roy.
  # 2. Add the private key to sops as `protonvpn-roy-wireguard-key`.
  # 3. Ensure Roy's age key is in .sops.yaml so secrets can be decrypted.
  # 4. Fill in address/peerPublicKey/endpoint below and set enable = true.
  protonVpn = {
    enable = true;
    namespace = "protonvpn";
    interface = "wg-proton";

    # From Proton's [Interface] Address field, e.g. "10.2.0.2/32".
    address = "10.2.0.2/32";
    # From Proton's [Interface] DNS field. Proton usually uses 10.2.0.1.
    dns = "10.2.0.1";

    # From Proton's [Peer] fields.
    peerPublicKey = "4RblBFy7/Vm2VT6SCyZJ1kKGOgdz2k+WxpNQKdw8mmc=";
    endpoint = "45.134.140.46:51820";
    allowedIPs = [ "0.0.0.0/0" ];

    # Proton's NAT-PMP gateway inside the WireGuard tunnel. This is used to
    # periodically renew a port-forward for rTorrent.
    natPmpGateway = "10.2.0.1";
    natPmpLifetimeSeconds = 60;
    natPmpRenewSeconds = 45;
  };

  protonResolvConf = pkgs.writeText "protonvpn-resolv.conf" ''
    nameserver ${protonVpn.dns}
  '';

  # Local HTTP hostnames for initial testing. Replace these with real domains
  # later, e.g. "jellyfin.example.com" and "music.example.com". Removing the
  # http:// prefix lets Caddy request/serve public HTTPS certificates.
  jellyfinHost = "jellyfin.whatgrabsme.org";
  navidromeHost = "navidrome.whatgrabsme.org";
  seerrHost = "seerr.whatgrabsme.org";
in
{
  users.groups.media = { };

  users.users.dillon.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "d ${mediaRoot} 0775 dillon media - -"
    "d ${mediaRoot}/library 0775 dillon media - -"
    "d ${mediaRoot}/library/music 0775 dillon media - -"
    "d ${mediaRoot}/library/movies 0775 dillon media - -"
    "d ${mediaRoot}/library/tv 0775 dillon media - -"
    "d ${mediaRoot}/torrents 0775 dillon media - -"
    "d ${mediaRoot}/torrents/complete 0775 rtorrent media - -"
    "d ${mediaRoot}/torrents/incomplete 0775 rtorrent media - -"
    "d ${mediaRoot}/appdata 0775 dillon media - -"
  ];

  services.jellyfin = {
    enable = true;
    # Keep Jellyfin itself private; Caddy is the public entrypoint.
    openFirewall = false;
    group = "media";
  };

  services.navidrome = {
    enable = true;
    # Keep Navidrome itself private; Caddy is the public entrypoint.
    openFirewall = false;
    group = "media";

    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "${mediaRoot}/library/music";
      DataFolder = "/var/lib/navidrome";
      EnableInsightsCollector = false;
    };
  };

  services.seerr = {
    enable = true;
    openFirewall = false;
    port = 5055;
  };

  # Arr stack. These are admin/download-management UIs, so keep them bound to
  # localhost for now. Configure them from Roy directly at:
  #   Radarr:   http://127.0.0.1:7878
  #   Sonarr:   http://127.0.0.1:8989
  #   Lidarr:       http://127.0.0.1:8686
  #   Prowlarr:     http://127.0.0.1:9696
  #   FlareSolverr: http://127.0.0.1:8191
  services.radarr = {
    enable = true;
    openFirewall = false;
    group = "media";
    settings = {
      server = {
        bindaddress = "127.0.0.1";
        port = 7878;
      };
      update.mechanism = "external";
      log.analyticsEnabled = false;
    };
  };

  services.sonarr = {
    enable = true;
    openFirewall = false;
    group = "media";
    settings = {
      server = {
        bindaddress = "127.0.0.1";
        port = 8989;
      };
      update.mechanism = "external";
      log.analyticsEnabled = false;
    };
  };

  services.lidarr = {
    enable = true;
    openFirewall = false;
    group = "media";
    settings = {
      server = {
        bindaddress = "127.0.0.1";
        port = 8686;
      };
      update.mechanism = "external";
      log.analyticsEnabled = false;
    };
  };

  services.prowlarr = {
    enable = true;
    openFirewall = false;
    settings = {
      server = {
        bindaddress = "127.0.0.1";
        port = 9696;
      };
      update.mechanism = "external";
      log.analyticsEnabled = false;
    };
  };

  # Internal-only Cloudflare challenge solver for Prowlarr indexer proxies.
  # Configure Prowlarr to use http://127.0.0.1:8191 for affected indexers.
  services.flaresolverr = {
    enable = true;
    openFirewall = false;
    port = 8191;
  };

  services.rtorrent = {
    enable = true;
    group = "media";
    dataDir = "${mediaRoot}/appdata/rtorrent";
    downloadDir = "${mediaRoot}/torrents/complete";
    dataPermissions = "0775";
    port = 50000;

    # This opens only the torrent peer port, not a web UI/RPC port.
    # Keep it closed once rTorrent is routed through ProtonVPN; the host
    # firewall cannot forward inbound peers to the VPN namespace anyway.
    openFirewall = !protonVpn.enable;

    # Use a modern rTorrent config instead of the NixOS module's default
    # `scgi_local` alias. Recent rTorrent treats that legacy SCGI endpoint as
    # untrusted, which lets status calls work but blocks Radarr/Sonarr/Lidarr
    # from adding torrents with commands like `load.start`.
    configText = lib.mkForce ''
      # Instance layout (base paths)
      method.insert = cfg.basedir, private|const|string, (cat,"${mediaRoot}/appdata/rtorrent/")
      method.insert = cfg.watch,   private|const|string, (cat,(cfg.basedir),"watch/")
      method.insert = cfg.logs,    private|const|string, (cat,(cfg.basedir),"log/")
      method.insert = cfg.logfile, private|const|string, (cat,(cfg.logs),(system.time),".log")
      method.insert = cfg.rpcsock, private|const|string, (cat,"/run/rtorrent/rpc.sock")

      # Create instance directories
      execute.throw = sh, -c, (cat, "mkdir -p ", (cfg.basedir), "/session ", (cfg.watch), " ", (cfg.logs))

      # Listening port for incoming peer traffic (fixed; you can also randomize it)
      network.port_range.set = 50000-50000
      network.port_random.set = no

      # Tracker-less torrent and UDP tracker support
      # Conservative defaults; revisit when we settle tracker/private-tracker usage.
      dht.mode.set = disable
      protocol.pex.set = no
      trackers.use_udp.set = no

      # Peer settings
      throttle.max_uploads.set = 100
      throttle.max_uploads.global.set = 250
      throttle.min_peers.normal.set = 20
      throttle.max_peers.normal.set = 60
      throttle.min_peers.seed.set = 30
      throttle.max_peers.seed.set = 80
      trackers.numwant.set = 80
      protocol.encryption.set = allow_incoming,try_outgoing,enable_retry

      # Resource limits
      network.http.max_open.set = 50
      network.max_open_files.set = 600
      network.max_open_sockets.set = 3000
      pieces.memory.max.set = 1800M
      network.xmlrpc.size_limit.set = 4M

      # Basic operational settings
      session.path.set = (cat, (cfg.basedir), "session/")
      directory.default.set = "${mediaRoot}/torrents/complete"
      log.execute = (cat, (cfg.logs), "execute.log")
      execute.nothrow = sh, -c, (cat, "echo >", (session.path), "rtorrent.pid", " ", (system.pid))

      # Make downloaded files group-writable so Radarr/Sonarr/Lidarr can import
      # and hardlink/copy them through the shared `media` group.
      encoding.add = utf8
      system.umask.set = 0002
      system.cwd.set = (cfg.basedir)
      network.http.dns_cache_timeout.set = 25
      schedule2 = monitor_diskspace, 15, 60, ((close_low_diskspace, 1000M))

      # Logging
      print = (cat, "Logging to ", (cfg.logfile))
      log.open_file = "log", (cfg.logfile)
      log.add_output = "info", "log"

      # XMLRPC/SCGI for ruTorrent and Arr download-client integration.
      # `network.scgi.open_local` is trusted for local Unix-socket access;
      # legacy `scgi_local` can cause `load.start is not allowed for untrusted
      # connections` with newer rTorrent.
      network.rpc.use_xmlrpc.set = true
      network.scgi.open_local = (cfg.rpcsock)
      network.scgi.dont_route.set = true
      schedule = scgi_group,0,0,"execute.nothrow=chown,\":media\",(cfg.rpcsock)"
      schedule = scgi_permission,0,0,"execute.nothrow=chmod,\"g+w,o=\",(cfg.rpcsock)"
    '';
  };

  services.rutorrent = {
    enable = true;
    hostName = "rutorrent.localhost";
    dataDir = "${mediaRoot}/appdata/rutorrent";
    group = "media";
    plugins = [
      # Do not enable `httprpc`: ruTorrent's httprpc bridge sends
      # UNTRUSTED_CONNECTION=1 for proxied XMLRPC calls. With recent rTorrent,
      # that can poison reused SCGI task slots and make Radarr/Sonarr/Lidarr
      # fail with `load.start is not allowed for untrusted connections`.
      # We expose the local /RPC2 SCGI bridge below instead.
      "data"
      "diskspace"
      "edit"
      "erasedata"
      "theme"
      "trafic"
      "rss"
    ];

    # The NixOS ruTorrent module currently manages an nginx/php-fpm vhost.
    # Bind nginx only to localhost:8081.
    nginx.enable = true;
  };

  # Let nginx/php-fpm talk to rTorrent's local SCGI Unix socket. Do this
  # manually instead of services.rutorrent.nginx.exposeInsecureRPC2mount because
  # that option forces rTorrent's group to `nginx`; we want rTorrent's group to
  # stay `media` for import permissions.
  users.users.nginx.extraGroups = [ "media" ];

  # The ruTorrent setup service copies plugins into a mutable appdata directory
  # but does not remove plugins when they are removed from the Nix list above.
  # Ensure the problematic httprpc plugin stays absent after rebuilds.
  systemd.services.rutorrent-remove-httprpc = {
    description = "Remove ruTorrent httprpc plugin";
    after = [ "rutorrent-setup.service" ];
    before = [ "phpfpm-rutorrent.service" "nginx.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      rm -rf ${mediaRoot}/appdata/rutorrent/plugins/httprpc
    '';
  };

  services.nginx.virtualHosts."rutorrent.localhost" = {
    listen = [
      {
        addr = "127.0.0.1";
        port = 8081;
        ssl = false;
      }
    ];

    # Local-only XMLRPC/SCGI bridge for Radarr/Sonarr/Lidarr download-client
    # integration. In the Arr UIs, use URL: http://127.0.0.1:8081/RPC2
    # Do not expose this vhost publicly; rTorrent RPC can execute commands.
    locations."/RPC2".extraConfig = ''
      include ${pkgs.nginx}/conf/scgi_params;
      # Recent rTorrent blocks mutating XMLRPC calls like `load.start` when
      # the SCGI request is marked untrusted. This endpoint is bound to
      # 127.0.0.1 only, so explicitly mark it trusted for local Arr clients.
      scgi_param UNTRUSTED_CONNECTION 0;
      scgi_pass unix:${config.services.rtorrent.rpcSocket};
    '';
  };

  # The ruTorrent module enables nginx, which enables nginx logrotate. On this
  # machine the generated runtime logrotate config check can fail before nginx
  # has useful logs to rotate. Caddy is the public-facing server here, so skip
  # nginx log rotation for this temporary local-only ruTorrent frontend.
  services.logrotate.settings.nginx.enable = false;

  services.caddy = {
    enable = true;

    virtualHosts.${jellyfinHost}.extraConfig = ''
      reverse_proxy 127.0.0.1:8096
    '';

    virtualHosts.${navidromeHost}.extraConfig = ''
      reverse_proxy 127.0.0.1:4533
    '';

    virtualHosts.${seerrHost}.extraConfig = ''
      reverse_proxy 127.0.0.1:5055
    '';

    # LAN-only friendly names. Use plain HTTP for home.arpa names to avoid
    # browser trust issues with local-only TLS certificates.
    virtualHosts."http://${lanHost "jellyfin"}".extraConfig = localOnlyReverseProxy "127.0.0.1:8096";
    virtualHosts."http://${lanHost "navidrome"}".extraConfig = localOnlyReverseProxy "127.0.0.1:4533";
    virtualHosts."http://${lanHost "seerr"}".extraConfig = localOnlyReverseProxy "127.0.0.1:5055";
    virtualHosts."http://${lanHost "radarr"}".extraConfig = localOnlyReverseProxy "127.0.0.1:7878";
    virtualHosts."http://${lanHost "sonarr"}".extraConfig = localOnlyReverseProxy "127.0.0.1:8989";
    virtualHosts."http://${lanHost "lidarr"}".extraConfig = localOnlyReverseProxy "127.0.0.1:8686";
    virtualHosts."http://${lanHost "prowlarr"}".extraConfig = localOnlyReverseProxy "127.0.0.1:9696";
    virtualHosts."http://${lanHost "rutorrent"}".extraConfig = localOnlyReverseProxy "127.0.0.1:8081";
  };

  # Lightweight local DNS for friendly LAN names and split-DNS for the public
  # media hostnames. Point your router's DHCP DNS setting at serverLanIp so LAN
  # clients use this resolver.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    settings = {
      no-resolv = true;
      domain-needed = true;
      bogus-priv = true;
      local = "/${lanDomain}/";
      domain = lanDomain;
      server = [
        "1.1.1.1"
        "9.9.9.9"
      ];
      address = [
        "/${lanHost "jellyfin"}/${serverLanIp}"
        "/${lanHost "navidrome"}/${serverLanIp}"
        "/${lanHost "seerr"}/${serverLanIp}"
        "/${lanHost "radarr"}/${serverLanIp}"
        "/${lanHost "sonarr"}/${serverLanIp}"
        "/${lanHost "lidarr"}/${serverLanIp}"
        "/${lanHost "prowlarr"}/${serverLanIp}"
        "/${lanHost "rutorrent"}/${serverLanIp}"
        "/${lanHost "roy"}/${serverLanIp}"

        # Split-DNS for public hostnames avoids router hairpin/NAT-loopback
        # issues when LAN clients use the public URLs.
        "/${jellyfinHost}/${serverLanIp}"
        "/${navidromeHost}/${serverLanIp}"
        "/${seerrHost}/${serverLanIp}"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  # Secondary LAN IP alias. Some routers require the DHCP primary/secondary DNS
  # to be two *different* addresses and won't accept a blank secondary. Giving
  # Roy a second address lets the router list `serverLanIp` as primary and this
  # alias as secondary, so both resolvers are still Roy's dnsmasq and home.arpa
  # names resolve no matter which one a client picks. dnsmasq doesn't bind to a
  # single address, so it answers on this alias with no extra config.
  # NOTE: keep secondaryLanIp outside the router's DHCP pool to avoid conflicts.
  systemd.services.lan-dns-alias = let
    secondaryLanIp = "192.168.1.55";
    lanInterface = "wlp0s20f3";
  in {
    description = "Secondary LAN IP alias so the router can point a distinct secondary DNS at Roy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.iproute2}/bin/ip addr replace ${secondaryLanIp}/24 dev ${lanInterface}";
      ExecStop = "${pkgs.iproute2}/bin/ip addr del ${secondaryLanIp}/24 dev ${lanInterface}";
    };
  };

  assertions = [
    {
      assertion = serverLanIp != "CHANGE-ME";
      message = "Set serverLanIp in hosts/roy/server_config.nix to Roy's reserved LAN address before building.";
    }
    {
      assertion = !protonVpn.enable || protonVpn.address != "CHANGE-ME/32";
      message = "Set protonVpn.address in hosts/roy/server_config.nix from Proton's WireGuard [Interface] Address before enabling Proton rTorrent VPN routing.";
    }
    {
      assertion = !protonVpn.enable || protonVpn.peerPublicKey != "CHANGE-ME";
      message = "Set protonVpn.peerPublicKey in hosts/roy/server_config.nix from Proton's WireGuard [Peer] PublicKey before enabling Proton rTorrent VPN routing.";
    }
    {
      assertion = !protonVpn.enable || protonVpn.endpoint != "CHANGE-ME.protonvpn.net:51820";
      message = "Set protonVpn.endpoint in hosts/roy/server_config.nix from Proton's WireGuard [Peer] Endpoint before enabling Proton rTorrent VPN routing.";
    }
  ];

  sops.secrets = lib.mkIf protonVpn.enable {
    protonvpn-roy-wireguard-key = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  networking.wireguard.interfaces.${protonVpn.interface} = lib.mkIf protonVpn.enable {
    # Create the WireGuard socket in the host namespace, then move the
    # interface into a dedicated namespace. rTorrent will run in that namespace,
    # which means it has no non-VPN route to leak through if WireGuard is down.
    interfaceNamespace = protonVpn.namespace;
    ips = [ protonVpn.address ];
    privateKeyFile = config.sops.secrets.protonvpn-roy-wireguard-key.path;

    preSetup = ''
      ${pkgs.iproute2}/bin/ip netns add ${protonVpn.namespace} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip -n ${protonVpn.namespace} link set lo up
    '';

    postShutdown = ''
      ${pkgs.iproute2}/bin/ip netns delete ${protonVpn.namespace} 2>/dev/null || true
    '';

    peers = [
      {
        publicKey = protonVpn.peerPublicKey;
        endpoint = protonVpn.endpoint;
        allowedIPs = protonVpn.allowedIPs;
        persistentKeepalive = 25;
      }
    ];
  };

  systemd.services.rtorrent = lib.mkIf protonVpn.enable {
    requires = [ "wireguard-${protonVpn.interface}.target" ];
    after = [ "wireguard-${protonVpn.interface}.target" ];
    bindsTo = [ "wireguard-${protonVpn.interface}.target" ];

    serviceConfig = {
      NetworkNamespacePath = "/run/netns/${protonVpn.namespace}";
      # rTorrent needs DNS inside the VPN namespace. The host's resolv.conf may
      # point at a LAN resolver or systemd-resolved stub that is unreachable from
      # this namespace, so bind Proton's VPN DNS just for this service.
      BindReadOnlyPaths = [ "${protonResolvConf}:/etc/resolv.conf" ];
    };
  };

  # Proton NAT-PMP port-forward renewal for rTorrent. Proton returns the public
  # forwarded port dynamically, but maps it to rTorrent's fixed local port. The
  # lease is short, so renew it on a timer while the VPN namespace is up.
  systemd.services.protonvpn-rtorrent-natpmp = lib.mkIf protonVpn.enable {
    description = "Renew ProtonVPN NAT-PMP port forward for rTorrent";
    requires = [ "wireguard-${protonVpn.interface}.target" ];
    after = [ "wireguard-${protonVpn.interface}.target" ];
    bindsTo = [ "wireguard-${protonVpn.interface}.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "protonvpn-rtorrent-natpmp" ''
        set -euo pipefail

        # libnatpmp's natpmpc can fail in a WireGuard-only network namespace
        # while trying to auto-detect a default gateway, even when -g is set.
        # Send the small NAT-PMP request directly to Proton's tunnel gateway.
        for attempt in $(seq 1 10); do
          if ${pkgs.iproute2}/bin/ip netns exec ${protonVpn.namespace} \
            ${pkgs.python3}/bin/python3 - <<'PY'
import socket, struct, sys, time

gateway = "${protonVpn.natPmpGateway}"
private_port = ${toString config.services.rtorrent.port}
public_port = ${toString config.services.rtorrent.port}
lifetime = ${toString protonVpn.natPmpLifetimeSeconds}

# NAT-PMP TCP mapping request: version, opcode, reserved, private, public, lifetime.
request = struct.pack("!BBHHHI", 0, 2, 0, private_port, public_port, lifetime)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.settimeout(5)
    sock.sendto(request, (gateway, 5351))
    data, _ = sock.recvfrom(16)

if len(data) < 16:
    raise SystemExit(f"short NAT-PMP response: {len(data)} bytes")
version, opcode, result, seconds, private, public, lifetime = struct.unpack("!BBHIHHI", data)
if version != 0 or opcode != 130:
    raise SystemExit(f"unexpected NAT-PMP response version/opcode: {version}/{opcode}")
if result != 0:
    raise SystemExit(f"NAT-PMP result code {result}")
print(f"ProtonVPN NAT-PMP mapped TCP public port {public} -> local port {private} for {lifetime}s")
PY
          then
            exit 0
          fi
          echo "NAT-PMP renewal attempt $attempt failed; retrying..." >&2
          sleep 3
        done

        exit 1
      '';
    };
  };

  systemd.timers.protonvpn-rtorrent-natpmp = lib.mkIf protonVpn.enable {
    description = "Renew ProtonVPN NAT-PMP port forward for rTorrent";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15s";
      OnUnitActiveSec = "${toString protonVpn.natPmpRenewSeconds}s";
      AccuracySec = "5s";
      Unit = "protonvpn-rtorrent-natpmp.service";
    };
  };

  environment.systemPackages = [ pkgs.wireguard-tools pkgs.libnatpmp ];
}
