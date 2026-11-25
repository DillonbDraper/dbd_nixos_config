# Public STUN/TURN for Roy. Credentials are decrypted by sops-nix at activation.
{ config, lib, pkgs, ... }:
let
  hostname = "turn.whatgrabsme.org";
  zone = "whatgrabsme.org";
  lanAddress = "192.168.1.54";
  gateway = "192.168.1.1";
  minRelayPort = 49152;
  maxRelayPort = 49407;
  stateDirectory = "/var/lib/conference-turn";
  certificateDirectory = "/var/lib/acme/${hostname}";
  secretsFile = ../../secrets/conference-turn.yaml;
  updater = ./conference_turn/netlify_dns.py;
  tokenPath = config.sops.secrets.conference-turn-netlify-token.path;
  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  checkToken = name: "${pkgs.python3}/bin/python3 ${updater} --check-token %d/${name}";
  certificateReady = ''
    ${pkgs.openssl}/bin/openssl verify -purpose sslserver \
      -verify_hostname ${lib.escapeShellArg hostname} -CAfile ${caBundle} \
      -untrusted ${certificateDirectory}/fullchain.pem \
      ${certificateDirectory}/fullchain.pem >/dev/null 2>&1
  '';
in
{
  sops.secrets = {
    conference-turn-netlify-token = {
      sopsFile = secretsFile;
      key = "netlify-token";
      mode = "0400";
      restartUnits = [ "conference-turn-dns.service" ];
    };
    conference-turn-secret = {
      sopsFile = secretsFile;
      key = "turn-shared-secret";
      owner = "turnserver";
      group = "turnserver";
      mode = "0400";
      restartUnits = [ "coturn.service" ];
    };
  };

  security.acme = {
    acceptTerms = true;
    certs.${hostname} = {
      email = "dillonbdraper@gmail.com";
      group = "turnserver";
      dnsProvider = "netlify";
      dnsResolver = "1.1.1.1:53";
      credentialFiles.NETLIFY_TOKEN_FILE = tokenPath;
      postRun = ''
        ${pkgs.systemd}/bin/systemctl --no-block restart coturn.service
      '';
    };
  };

  # The initial encrypted token is a placeholder. Skip issuance until it is
  # replaced, while keeping existing system secrets/services operational.
  systemd.services."acme-order-renew-${hostname}".serviceConfig.ExecCondition =
    checkToken "NETLIFY_TOKEN_FILE";

  services.coturn = {
    enable = true;
    listening-ips = [ lanAddress ];
    relay-ips = [ lanAddress ];
    listening-port = 3478;
    tls-listening-port = 5349;
    min-port = minRelayPort;
    max-port = maxRelayPort;
    realm = hostname;
    use-auth-secret = true;
    static-auth-secret-file = config.sops.secrets.conference-turn-secret.path;
    cert = "${certificateDirectory}/fullchain.pem";
    pkey = "${certificateDirectory}/key.pem";
    no-cli = true;
    no-dtls = true;
    no-tcp-relay = true;
    extraConfig = ''
      fingerprint
      no-multicast-peers
      no-tlsv1
      no-tlsv1_1
      denied-peer-ip=0.0.0.0-0.255.255.255
      denied-peer-ip=10.0.0.0-10.255.255.255
      denied-peer-ip=100.64.0.0-100.127.255.255
      denied-peer-ip=127.0.0.0-127.255.255.255
      denied-peer-ip=169.254.0.0-169.254.255.255
      denied-peer-ip=172.16.0.0-172.31.255.255
      denied-peer-ip=192.168.0.0-192.168.255.255
      denied-peer-ip=224.0.0.0-255.255.255.255
      denied-peer-ip=::1
      denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      log-file=stdout
      simple-log
    '';
  };

  systemd.services.coturn = {
    wants = [ "acme-${hostname}.service" ];
    after = [ "acme-${hostname}.service" "conference-turn-dns.service" ];
    unitConfig.ConditionPathExists = "${stateDirectory}/external-ip.conf";
    preStart = lib.mkAfter ''
      cat ${stateDirectory}/external-ip.conf >> /run/coturn/turnserver.cfg
    '';
    # NixOS creates a temporary self-signed certificate before ACME completes.
    # Wait for a publicly trusted hostname-matching certificate instead.
    serviceConfig.ExecCondition = pkgs.writeShellScript "conference-turn-certificate-ready" certificateReady;
  };

  systemd.services.conference-turn-dns = {
    description = "Synchronize TURN DNS and coturn's public address";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.python3 pkgs.openssl pkgs.systemd pkgs.coreutils ];
    environment.SSL_CERT_FILE = caBundle;
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "turnserver";
      StateDirectory = "conference-turn";
      StateDirectoryMode = "0750";
      UMask = "0027";
      LoadCredential = "netlify-token:${tokenPath}";
      ExecCondition = checkToken "netlify-token";
      TimeoutStartSec = "120s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    };
    script = ''
      python3 ${updater} --token-file "$CREDENTIALS_DIRECTORY/netlify-token" \
        --zone ${lib.escapeShellArg zone} --hostname ${lib.escapeShellArg hostname} \
        --lan-address ${lib.escapeShellArg lanAddress} --state-directory ${stateDirectory}

      if ! ( ${certificateReady} ); then
        systemctl --no-block start acme-order-renew-${hostname}.service
      fi
      if [ -f ${stateDirectory}/restart-required ]; then
        systemctl --no-block restart coturn.service
        rm ${stateDirectory}/restart-required
      else
        systemctl --no-block start coturn.service
      fi
    '';
  };

  systemd.timers.conference-turn-dns = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitInactiveSec = "60s";
      RandomizedDelaySec = "5s";
      Unit = "conference-turn-dns.service";
    };
  };

  # Spectrum's single-port UI cannot express the relay range. Its gateway
  # supports NAT-PMP alongside UPnP, with reliable port/lease confirmation.
  # Replies use an established UDP flow, so no SSDP firewall exception is needed.
  systemd.services.conference-turn-port-mappings = {
    description = "Maintain TURN router port mappings";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      ExecStart = "${pkgs.python3}/bin/python3 ${./conference_turn/port_mappings.py} --gateway ${gateway} --lan-address ${lanAddress} --min-port ${toString minRelayPort} --max-port ${toString maxRelayPort}";
      TimeoutStartSec = "600s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
    };
  };

  systemd.timers.conference-turn-port-mappings = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitInactiveSec = "5min";
      RandomizedDelaySec = "5s";
      Unit = "conference-turn-port-mappings.service";
    };
  };

  environment.systemPackages = [
    pkgs.tcpdump
    (pkgs.writeShellApplication {
      name = "conference-turn-test-credentials";
      runtimeInputs = [ pkgs.python3 pkgs.sops ];
      text = ''
        exec python3 ${./conference_turn/test_credentials.py} "$@"
      '';
    })
  ];

  networking.firewall = {
    allowedTCPPorts = [ 3478 5349 ];
    allowedUDPPorts = [ 3478 ];
    allowedUDPPortRanges = [ { from = minRelayPort; to = maxRelayPort; } ];
  };

  system.build.conference-turn-checks = pkgs.runCommand "conference-turn-checks" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    cp ${updater} netlify_dns.py
    cp ${./conference_turn/test_netlify_dns.py} test_netlify_dns.py
    cp ${./conference_turn/port_mappings.py} port_mappings.py
    cp ${./conference_turn/test_credentials.py} test_credentials.py
    cp ${./conference_turn/test_port_mappings.py} test_port_mappings.py
    python3 -m unittest -v
    touch "$out"
  '';
}
