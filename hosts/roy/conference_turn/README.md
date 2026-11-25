# Roy conference TURN deployment

The module serves `turn.whatgrabsme.org` using coturn on Roy's reserved LAN IP,
`192.168.1.54`. Caddy retains TCP 80/443. TURN uses UDP/TCP 3478, TLS/TCP 5349,
and UDP relay ports 49152-49407. DNS-based certificate validation needs no
additional port-80 forwarding.

## Credentials

`secrets/conference-turn.yaml` is a separate SOPS-encrypted file using the existing
age recipient. It contains:

- `netlify-token`: initially `REPLACE_WITH_NETLIFY_TOKEN`; replace this with a
  Netlify personal access token authorized to manage the `whatgrabsme.org` DNS
  zone. The same token is used for DNS updates and ACME DNS validation.
- `turn-shared-secret`: a generated random secret, already populated. Retain it;
  the Phoenix application needs this same value through its own secret file.

Edit with `sops secrets/conference-turn.yaml`. Never put plaintext credentials in
the module, shell command arguments, Git, or chat. With NixOS activated, SOPS
installs `/run/secrets/conference-turn-netlify-token` (root-only) and
`/run/secrets/conference-turn-secret` (readable by coturn's `turnserver` account).
Systemd copies the API token into private credentials directories for each job.

The placeholder is intentional: the DNS and ACME jobs skip until a real token is
installed. Coturn waits for both its public-address mapping and a publicly trusted
hostname-matching certificate. NixOS's initial self-signed certificate is not used
to start the public TURN listener.

## Apply

This checkout has unrelated existing work; the TURN change adds its module,
helper/tests, encrypted credentials file, and one Roy import. Review the complete
system rebuild before switching, especially if Roy's running generation is older
than this checkout.

The source checkout on Marth is `~/dbd_nixos_config`; Roy's existing checkout is
`~/nixos_config`. The module is imported in both. Only the TURN files and import
were copied to Roy; its other local configuration changes were preserved.

From either checkout, evaluate/build checks without activating the system:

    nix build --no-write-lock-file path:.#nixosConfigurations.roy.config.system.build.conference-turn-checks --no-link
    nix build --no-write-lock-file path:.#nixosConfigurations.roy.config.system.build.toplevel --no-link

`path:.` includes the newly created files without requiring a Git commit or
changing your staging area. Once the credentials are populated, activate from
Roy with an interactive sudo session:

    cd ~/nixos_config
    sops secrets/conference-turn.yaml
    sudo nixos-rebuild switch --flake path:.#roy

Replace only `netlify-token` in the SOPS editor; keep the generated shared secret.
Keep the encrypted credential file synchronized between the two checkouts. Copy
the encrypted YAML, not plaintext values. The SSH session used for staging could
not run sudo noninteractively, so file installation/building is separate from
activating the running system.

After changing the encrypted token, rebuild/apply again so sops-nix installs it.
Secret changes request a restart of the relevant service. The timer also retries
automatically, or start it immediately:

    sudo systemctl start conference-turn-dns.service

## Router and DNS

The My Spectrum app's port-assignment fields accept individual ports. Enable
UPnP in the router's Advanced Settings; the module's
`conference-turn-port-mappings` service uses the gateway's NAT-PMP interface to
maintain these mappings to Roy, preserving port numbers:

| External | Internal | Protocol |
| --- | --- | --- |
| 3478 | 3478 | UDP and TCP |
| 5349 | 5349 | TCP |
| 49152-49407 | 49152-49407 | UDP |

The service confirms all 259 mappings, requests one-hour leases, and starts a new
pass five minutes after each completed pass. It runs from a timer on boot and
retries after router restarts. Each pass takes several minutes because requests
are paced for this gateway; progress is reported every 64 ports.
It refuses an alternative public port and releases that alternative allocation.
It needs no API token or root privileges and does not manage other ports.

    systemctl status conference-turn-port-mappings.timer conference-turn-port-mappings.service
    journalctl -u conference-turn-port-mappings.service -n 10

The gateway is `192.168.1.1`. UPnP discovery from Roy needs a permitted source
port because the normal SSDP replies do not match the firewall's established
flows. Discovery using `upnpc -m 192.168.1.54 -z 49152 -l` succeeded, but the
gateway's `GetSpecificPortMappingEntry` returned malformed internal-address XML.
NAT-PMP's binary mapping confirmations worked for this router and avoid that
problem. Keep UPnP enabled while using these automatic mappings.

The updater creates/manages only the A record for `turn.whatgrabsme.org`; it
leaves other hostnames and certificate TXT records alone. It refuses a conflicting
CNAME/AAAA record. Do not manually create a competing record. It requests a
300-second TTL when creating a record and creates replacements before deleting
old A records. No registrar/name-server change is needed.

The updater lists the DNS zones visible to the token, matches `whatgrabsme.org`,
and uses that zone's API ID for record requests. A DNS domain is not necessarily
Netlify's zone-name slug; requesting `/dns_zones/whatgrabsme.org` can return 404
even with a valid token. HTTP failures include the request method/path, while
credentials and response bodies are omitted from logs.

A systemd timer checks the public IPv4 roughly every minute using HTTPS, updates
Netlify, writes coturn's public/private mapping atomically, and restarts the relay
only when its mapping changes. API/discovery failure preserves the last mapping.
An ISP address change can interrupt calls, and cached DNS can delay reconnection.

Test household clients as well as external clients: public relay candidates may
require router NAT reflection even when local DNS reaches the listener directly.
The current setup does not add a local-only DNS override for the TURN hostname.

## Inspect and verify

    systemctl status conference-turn-dns.timer conference-turn-dns.service coturn.service
    systemctl status acme-order-renew-turn.whatgrabsme.org.service
    journalctl -u conference-turn-dns -u acme-order-renew-turn.whatgrabsme.org -u coturn

Before the API token is supplied, a skipped DNS/ACME job and inactive coturn are
expected. After supplying it, verify DNS, trusted TLS on 5349, and authenticated
relay allocations from another network. Force UDP, TCP, and TLS individually;
an ordinary direct call does not prove relay use. Check real audio/video, failed
credentials, renewals, and cleanup. TLS on 5349 does not cover 443-only networks.

### First outside-network browser test

After applying the module, run as dillon on Roy:

    cd ~/nixos_config
    conference-turn-test-credentials

This decrypts only the TURN secret in memory and prints a temporary username and
password valid for 15 minutes. It does not print the shared secret or API token.
Use a laptop connected to a phone hotspot, with home Wi-Fi disconnected. Open
[Trickle ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/),
remove its default ICE servers, choose `relay`, and add one URL at a time:

| Test | STUN or TURN URI |
| --- | --- |
| UDP | `turn:turn.whatgrabsme.org:3478?transport=udp` |
| TCP | `turn:turn.whatgrabsme.org:3478?transport=tcp` |
| TLS | `turns:turn.whatgrabsme.org:5349?transport=tcp` |

Paste the generated username/password, click Add Server, then Gather candidates.
Each test should produce a row whose type is `relay`, with a public address and
a port between 49152 and 49407. Remove the previous URL before testing the next.
If the credentials expire, run the command again and replace them. Repeat on
home Wi-Fi to check NAT reflection. A relay candidate proves allocation, not
end-to-end media; the next gate is a forced-relay call through the actual app.

The 22 Mbit/s home upload is a shared capacity budget, not a guaranteed room count.
Measure real five-person traffic alongside the existing media services before
choosing operational quotas or accepting production concurrency.

## Phoenix configuration

Provision this separately on the app host. Set `CONFERENCE_ICE_CONFIG` to the JSON
file's path, and securely provision the decrypted TURN shared secret to its
`secret_file` path. The Netlify API token is not needed by Phoenix.

    {
      "stun_urls": ["stun:turn.whatgrabsme.org:3478"],
      "turn_urls": [
        "turn:turn.whatgrabsme.org:3478?transport=udp",
        "turn:turn.whatgrabsme.org:3478?transport=tcp",
        "turns:turn.whatgrabsme.org:5349?transport=tcp"
      ],
      "secret_file": "/run/secrets/conference-turn",
      "ttl_seconds": 3600
    }
