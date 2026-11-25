"""Maintain one Netlify A record and coturn's matching public/private mapping."""

import argparse
import ipaddress
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request


TOKEN_PLACEHOLDER = "REPLACE_WITH_NETLIFY_TOKEN"


class UpdateError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise UpdateError("Unexpected HTTP redirect; refusing to forward credentials")


def token_from(path):
    try:
        token = Path(path).read_text().strip()
    except FileNotFoundError:
        return None
    if not token or token == TOKEN_PLACEHOLDER:
        return None
    if not token.isascii() or any(char.isspace() for char in token):
        raise UpdateError("The Netlify token file must contain only the token")
    return token


def public_ipv4(value):
    try:
        address = ipaddress.IPv4Address(value.strip())
    except ipaddress.AddressValueError:
        raise UpdateError("Public-address discovery did not return an IPv4 address") from None
    if not address.is_global:
        raise UpdateError("Refusing to publish a non-public IPv4 address")
    return str(address)


def discover_address(opener):
    for endpoint in ("https://api.ipify.org", "https://ipv4.icanhazip.com"):
        try:
            with opener.open(endpoint, timeout=10) as response:
                return public_ipv4(response.read(256).decode("ascii"))
        except (OSError, UnicodeError, UpdateError):
            continue
    raise UpdateError("Public IPv4 discovery failed; retaining the previous configuration")


class Netlify:
    def __init__(self, token, opener=None):
        self.token = token
        self.opener = opener or urllib.request.build_opener(NoRedirect())

    def request(self, method, path, data=None):
        request = urllib.request.Request(
            "https://api.netlify.com/api/v1" + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={
                "Authorization": "Bearer " + self.token,
                "Content-Type": "application/json",
                "User-Agent": "roy-conference-turn/1",
            },
            method=method,
        )
        try:
            with self.opener.open(request, timeout=20) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            raise UpdateError(f"Netlify {method} {path} failed (HTTP {error.code})") from None
        except (OSError, ValueError):
            raise UpdateError("Netlify DNS request failed; retaining the previous configuration") from None


def synchronize_record(api, zone, hostname, address, ttl):
    # Netlify's zone-name slug can differ from its DNS domain. Resolve the
    # configured domain to its API ID instead of assuming the domain is a slug.
    # Never create a missing zone or choose between ambiguous matches.
    zones = api.request("GET", "/dns_zones")
    if not isinstance(zones, list):
        raise UpdateError("Netlify returned an invalid DNS zone list")
    matches = [item for item in zones if isinstance(item, dict) and zone in (item.get("name"), item.get("domain"))]
    if not matches:
        raise UpdateError(f"The Netlify token cannot access DNS zone {zone}")
    if len(matches) != 1 or not isinstance(matches[0].get("id"), str) or not matches[0]["id"]:
        raise UpdateError("Netlify did not return one unambiguous DNS zone ID")
    zone_data = matches[0]
    path = "/dns_zones/" + urllib.parse.quote(zone_data["id"], safe="") + "/dns_records"
    records = api.request("GET", path)
    if not isinstance(records, list):
        raise UpdateError("Netlify returned an invalid DNS record list")
    own = [record for record in records if record.get("hostname", "").rstrip(".").lower() == hostname]
    if any(record.get("type") in ("CNAME", "AAAA") for record in own):
        raise UpdateError("The TURN hostname has a CNAME/AAAA record; resolve that conflict first")
    addresses = [record for record in own if record.get("type") == "A"]
    keep = next((record for record in addresses if record.get("value") == address), None)
    if keep is None:
        keep = api.request("POST", path, {"type": "A", "hostname": hostname, "value": address, "ttl": ttl})
        if not keep or not keep.get("id") or keep.get("value") != address or keep.get("type") != "A":
            raise UpdateError("Netlify did not confirm the replacement A record")
    # Create before deleting. Retries repair partial updates without touching
    # other hostnames or the TXT records used by ACME DNS validation.
    for record in addresses:
        if record["id"] != keep["id"]:
            api.request("DELETE", path + "/" + urllib.parse.quote(record["id"], safe=""))


def write_mapping(directory, address, lan_address):
    path = directory / "external-ip.conf"
    contents = f"external-ip={address}/{lan_address}\n"
    if path.exists() and path.read_text() == contents:
        return False
    descriptor, temporary = tempfile.mkstemp(dir=directory, prefix=".external-ip-")
    try:
        with os.fdopen(descriptor, "w") as output:
            os.fchmod(output.fileno(), 0o640)
            output.write(contents)
            output.flush()
            os.fsync(output.fileno())
        # Persist restart intent first, so an interrupted updater cannot install
        # a new mapping without notifying the running relay on the next pass.
        (directory / "restart-required").touch(mode=0o640)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return True


def reconcile(api, zone, hostname, address, lan_address, directory, ttl=300):
    address = public_ipv4(address)
    lan_address = str(ipaddress.IPv4Address(lan_address))
    if hostname == zone or not hostname.endswith("." + zone):
        raise UpdateError("Only a subdomain of the configured DNS zone may be managed")
    synchronize_record(api, zone, hostname, address, ttl)
    return write_mapping(directory, address, lan_address)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-token", type=Path)
    parser.add_argument("--token-file", type=Path)
    parser.add_argument("--zone")
    parser.add_argument("--hostname")
    parser.add_argument("--lan-address")
    parser.add_argument("--state-directory", type=Path)
    args = parser.parse_args()
    if not (args.check_token or args.token_file):
        parser.error("--check-token or --token-file is required")
    try:
        token = token_from(args.check_token or args.token_file)
        if token is None:
            print("Waiting for the Netlify token in the conference TURN SOPS file")
            return 1
        if args.check_token:
            return 0
        if not all((args.zone, args.hostname, args.lan_address, args.state_directory)):
            parser.error("zone, hostname, LAN address and state directory are required")
        api = Netlify(token)
        address = discover_address(api.opener)
        changed = reconcile(api, args.zone, args.hostname, address, args.lan_address, args.state_directory)
        print("TURN DNS synchronized; " + ("public address changed" if changed else "public address unchanged"))
        return 0
    except (UpdateError, OSError, ValueError) as error:
        print(f"Conference TURN updater: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
