# Media-server stack for Roy (always-on laptop server).
# Ported from hosts/marth/server_config.nix.
# Before first `nixos-rebuild switch`, set serverLanIp to Roy's reserved LAN address.
{ config, lib, pkgs, ... }:

let
  mediaRoot = "/svr/newDrive/media";

  # Pin the media group's gid to its current value on Roy so the soularr
  # container can join it by number (a container can't resolve host group names).
  # This equals the existing auto-assigned gid, so no files get re-chowned.
  mediaGid = 982;

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

    # veth pair bridging the host namespace and the protonvpn namespace so
    # services in the host ns (Caddy, the soularr container) can reach slskd's
    # web API while slskd itself stays confined to the VPN namespace. Only this
    # tiny /30 is routed over the veth; the namespace's default route remains the
    # WireGuard interface, so all Soulseek traffic still egresses through the VPN.
    veth = {
      # Interface names must be <= 15 characters (IFNAMSIZ), so keep these short.
      host = "vproton-host";
      ns = "vproton-ns";
      hostAddr = "10.200.0.1";
      nsAddr = "10.200.0.2";
      prefixLength = 30;
    };
  };

  protonResolvConf = pkgs.writeText "protonvpn-resolv.conf" ''
    nameserver ${protonVpn.dns}
  '';

  # slskd runs inside the protonvpn namespace; its web/API is reached from the
  # host (and proxied by Caddy / consumed by soularr) over the veth address.
  slskdPort = 5030;
  slskdApiUrl = "http://${protonVpn.veth.nsAddr}:${toString slskdPort}";
  slskdDownloadDir = "${mediaRoot}/soulseek/complete";
  slskdIncompleteDir = "${mediaRoot}/soulseek/incomplete";

  lidarrApiUrl = "http://127.0.0.1:8686";

  # Local HTTP hostnames for initial testing. Replace these with real domains
  # later, e.g. "jellyfin.example.com" and "music.example.com". Removing the
  # http:// prefix lets Caddy request/serve public HTTPS certificates.
  jellyfinHost = "jellyfin.whatgrabsme.org";
  navidromeHost = "navidrome.whatgrabsme.org";
  seerrHost = "seerr.whatgrabsme.org";
in
{
  users.groups.media = { gid = mediaGid; };

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
    # slskd (Soulseek) downloads. Owned by dillon:media like the other media
    # dirs (not slskd) so systemd-tmpfiles doesn't reject creation with an
    # "unsafe path transition" — a non-root owner change mid-path. slskd writes
    # here as a member of the media group (mode 0775), same as rtorrent.
    "d ${mediaRoot}/soulseek 0775 dillon media - -"
    "d ${slskdDownloadDir} 0775 dillon media - -"
    "d ${slskdIncompleteDir} 0775 dillon media - -"
  ];

  services.jellyfin = {
    enable = true;
    # Open Jellyfin's own ports to the LAN so phone/TV clients can reach it
    # directly at http://<serverLanIp>:8096 (and via LAN auto-discovery) without
    # relying on DNS. This only exposes Jellyfin to devices already on the LAN;
    # the router does not forward 8096 from the internet. Caddy
    # (jellyfin.whatgrabsme.org) remains the public/remote entrypoint.
    openFirewall = true;
    group = "media";
  };

  services.navidrome = {
    enable = true;
    # Expose Navidrome on the LAN so phone/TV clients can reach it directly at
    # http://<serverLanIp>:4533 without DNS. Binding to 0.0.0.0 is required in
    # addition to opening the firewall, since the default 127.0.0.1 bind refuses
    # LAN connections. Only LAN devices can reach it; the router does not forward
    # 4533 from the internet. Caddy stays the public/remote entrypoint.
    openFirewall = true;
    group = "media";

    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "${mediaRoot}/music";
      DataFolder = "/var/lib/navidrome";
      EnableInsightsCollector = false;
    };
  };

  services.seerr = {
    enable = true;
    # Expose Seerr on the LAN so phone/TV clients can reach it directly at
    # http://<serverLanIp>:5055 without DNS. Seerr already listens on all
    # interfaces, so opening the firewall is sufficient. LAN-only; the router
    # does not forward 5055 from the internet.
    openFirewall = true;
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

  # slskd: Soulseek daemon driven by soularr. Runs inside the protonvpn network
  # namespace (see the systemd override below) so all Soulseek traffic egresses
  # through the VPN. Its web/API is reached from the host over the veth at
  # ${slskdApiUrl}. Soulseek credentials, the web-UI login, and the soularr API
  # key are supplied via the sops-rendered environment file (never the nix
  # store). slskd has no inbound port-forward (ProtonVPN's single NAT-PMP forward
  # is already used by rTorrent), so it operates in passive mode.
  services.slskd = {
    enable = true;
    openFirewall = false;
    group = "media";
    domain = null;
    environmentFile = config.sops.templates."slskd.env".path;
    settings = {
      soulseek.listen_port = 50300;
      directories = {
        downloads = slskdDownloadDir;
        incomplete = slskdIncompleteDir;
      };
      # Share the music library back to Soulseek (good etiquette; many peers
      # refuse to upload to non-sharing users). Traffic goes through the VPN.
      shares.directories = [ "${mediaRoot}/library/music" ];
      shares.filters = [ ];
      web.port = slskdPort;
    };
  };

  # soularr: bridges Lidarr's wanted list to slskd and triggers Lidarr import.
  # Runs as a Podman container (its slskd-api Python dep is not in nixpkgs).
  # --network=host lets it reach Lidarr (127.0.0.1:8686) and slskd (veth) at
  # once. The slskd download dir is mounted at an identical path so the paths
  # soularr hands to Lidarr for import line up on both sides.
  #
  # Run as root:media with a group-writable umask. soularr builds the import
  # folders it hands to Lidarr; as bare root those came out root:root, so Lidarr
  # (which runs as group media) could copy the tracks to the library but then
  # could not delete the source during its move-import -> UnauthorizedAccess.
  # Keeping uid 0 lets soularr still read the root-owned config and write /data;
  # gid media + umask 0002 makes everything it creates group-writable so Lidarr
  # can import and clean up.
  virtualisation.oci-containers = {
    backend = "podman";
    containers.soularr = {
      image = "mrusse08/soularr:latest";
      autoStart = true;
      extraOptions = [
        "--network=host"
        "--user=0:${toString mediaGid}"
        "--umask=0002"
      ];
      environment = {
        SCRIPT_INTERVAL = "300";
        TZ = "America/Chicago";
      };
      volumes = [
        "${config.sops.templates."soularr-config.ini".path}:/data/config.ini:ro"
        "${slskdDownloadDir}:${slskdDownloadDir}"
      ];
    };
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
    virtualHosts."http://${lanHost "slskd"}".extraConfig = localOnlyReverseProxy "${protonVpn.veth.nsAddr}:${toString slskdPort}";
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
        "/${lanHost "slskd"}/${serverLanIp}"
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

  # Secrets for slskd + soularr. Populate these in secrets/secrets.yaml with
  # `sops secrets/secrets.yaml` before switching:
  #   slskd-soulseek-username/password : your Soulseek (Nicotine) account
  #   slskd-web-username/password       : login for the slskd web UI
  #   slskd-api-key                     : `openssl rand -hex 32`, shared with soularr
  #   lidarr-api-key                    : from Lidarr > Settings > General (after it runs)
  sops.secrets = lib.mkMerge [
    (lib.mkIf protonVpn.enable {
      protonvpn-roy-wireguard-key = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    })
    {
      slskd-soulseek-username = { };
      slskd-soulseek-password = { };
      slskd-web-username = { };
      slskd-web-password = { };
      slskd-api-key = { };
      lidarr-api-key = { };
    }
  ];

  # Environment file for slskd (read by systemd as root, never in the nix store).
  # slskd maps SLSKD_-prefixed vars onto its config; a single primary API key is
  # set with the `role=...;cidr=...;<key>` form. Administrator role lets soularr
  # queue downloads and import.
  sops.templates."slskd.env".content = ''
    SLSKD_SLSK_USERNAME=${config.sops.placeholder."slskd-soulseek-username"}
    SLSKD_SLSK_PASSWORD=${config.sops.placeholder."slskd-soulseek-password"}
    SLSKD_USERNAME=${config.sops.placeholder."slskd-web-username"}
    SLSKD_PASSWORD=${config.sops.placeholder."slskd-web-password"}
    SLSKD_API_KEY=role=Administrator;cidr=0.0.0.0/0,::/0;${config.sops.placeholder."slskd-api-key"}
  '';

  # soularr's config.ini, rendered with the Lidarr + slskd API keys. Connection
  # hosts/dirs are wired to this deployment; the remaining tunables are soularr's
  # documented defaults. download_dir is identical on both sides because the
  # slskd downloads path is bind-mounted into the container unchanged.
  sops.templates."soularr-config.ini".content = ''
    [Lidarr]
    api_key = ${config.sops.placeholder."lidarr-api-key"}
    host_url = ${lidarrApiUrl}
    download_dir = ${slskdDownloadDir}
    disable_sync = False

    [Slskd]
    api_key = ${config.sops.placeholder."slskd-api-key"}
    host_url = ${slskdApiUrl}
    url_base = /
    download_dir = ${slskdDownloadDir}
    delete_searches = False
    stalled_timeout = 3600
    remote_queue_timeout = 300

    [Release Settings]
    use_selected_lidarr_release = True
    use_most_common_tracknum = True
    allow_multi_disc = True
    accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
    skip_region_check = False
    accepted_formats = CD,Digital Media,Vinyl

    [Search Settings]
    search_timeout = 5000
    maximum_peer_queue = 50
    minimum_peer_upload_speed = 0
    minimum_filename_match_ratio = 0.8
    minimum_search_interval = 5
    allowed_filetypes = flac 24/192,flac 16/44.1,flac,mp3 320,mp3
    ignored_users =
    album_prepend_artist = False
    search_type = incrementing_page
    number_of_albums_to_grab = 10
    title_blacklist =
    search_blacklist =
    search_source = missing
    failed_import_denylist = False

    [Download Settings]
    download_filtering = True
    use_extension_whitelist = False
    extensions_whitelist = lrc,nfo,txt

    [Logging]
    level = INFO
    format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
    datefmt = %Y-%m-%dT%H:%M:%S%z
    log_to_file = False
    log_file = soularr.log
    max_bytes = 1048576
    backup_count = 3
  '';

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

      # veth pair so the host can reach slskd's web/API inside the namespace.
      # The namespace keeps its WireGuard default route, so only this /30 is
      # local; all other traffic (Soulseek) still goes through the VPN.
      ${pkgs.iproute2}/bin/ip link del ${protonVpn.veth.host} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip link add ${protonVpn.veth.host} type veth peer name ${protonVpn.veth.ns}
      ${pkgs.iproute2}/bin/ip link set ${protonVpn.veth.ns} netns ${protonVpn.namespace}
      ${pkgs.iproute2}/bin/ip addr add ${protonVpn.veth.hostAddr}/${toString protonVpn.veth.prefixLength} dev ${protonVpn.veth.host}
      ${pkgs.iproute2}/bin/ip link set ${protonVpn.veth.host} up
      ${pkgs.iproute2}/bin/ip -n ${protonVpn.namespace} addr add ${protonVpn.veth.nsAddr}/${toString protonVpn.veth.prefixLength} dev ${protonVpn.veth.ns}
      ${pkgs.iproute2}/bin/ip -n ${protonVpn.namespace} link set ${protonVpn.veth.ns} up
    '';

    postShutdown = ''
      ${pkgs.iproute2}/bin/ip link del ${protonVpn.veth.host} 2>/dev/null || true
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

  # Confine slskd to the same ProtonVPN namespace as rTorrent. It binds all
  # interfaces inside the namespace, so the host reaches its web/API over the
  # veth at ${slskdApiUrl}, while Soulseek traffic egresses through the VPN.
  systemd.services.slskd = lib.mkIf protonVpn.enable {
    requires = [ "wireguard-${protonVpn.interface}.target" ];
    after = [ "wireguard-${protonVpn.interface}.target" ];
    bindsTo = [ "wireguard-${protonVpn.interface}.target" ];

    serviceConfig = {
      NetworkNamespacePath = "/run/netns/${protonVpn.namespace}";
      BindReadOnlyPaths = [ "${protonResolvConf}:/etc/resolv.conf" ];
      # Make completed downloads group-writable so Lidarr can import them.
      UMask = "0002";
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
