"""Print 15-minute coturn REST credentials for the operator's Trickle ICE test."""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import hmac
from pathlib import Path
import secrets
import subprocess
import sys
import time


def credentials(secret, now):
    if len(secret) < 32:
        raise ValueError("TURN shared secret must contain at least 32 bytes")
    expiry = int(now) + 900
    username = f"{expiry}:operator-{secrets.token_hex(4)}"
    password = base64.b64encode(hmac.new(secret, username.encode(), hashlib.sha1).digest()).decode()
    return username, password, expiry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sops-file", type=Path, default=Path("secrets/conference-turn.yaml"))
    args = parser.parse_args()
    try:
        result = subprocess.run(
            ["sops", "--decrypt", "--extract", '["turn-shared-secret"]', str(args.sops_file)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        if result.returncode:
            print("Cannot decrypt TURN credentials. Run this as dillon from ~/nixos_config.", file=sys.stderr)
            return 1
        username, password, expiry = credentials(result.stdout.strip(), time.time())
    except (OSError, ValueError) as error:
        print(f"Cannot generate test credentials: {error}", file=sys.stderr)
        return 1
    print("Expires:", datetime.fromtimestamp(expiry, timezone.utc).isoformat())
    print("TURN username:", username)
    print("TURN password:", password)
    print("Use these temporary credentials with each TURN URL; the shared secret stays private.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
