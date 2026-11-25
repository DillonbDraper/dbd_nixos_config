"""Maintain matching public/private TURN ports through the home gateway's NAT-PMP service."""

import argparse
import socket
import struct
import sys
import time


class MappingError(Exception):
    pass


def exchange(client, protocol, port, lifetime):
    opcode = {"UDP": 1, "TCP": 2}[protocol]
    request = struct.pack("!BBHHHI", 0, opcode, 0, port, port, lifetime)
    for timeout in (2, 3, 4, 8):
        client.send(request)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            client.settimeout(max(0.001, deadline - time.monotonic()))
            try:
                response = client.recv(64)
            except socket.timeout:
                break
            if len(response) < 8 or response[0] != 0 or response[1] != opcode + 128:
                continue
            status = struct.unpack("!H", response[2:4])[0]
            if status in (3, 4):
                # The gateway occasionally reports temporary network/resource
                # failure during a range update. Retry with bounded backoff.
                time.sleep(timeout)
                break
            if status:
                raise MappingError(f"Gateway refused {protocol} {port} (NAT-PMP result {status})")
            if len(response) != 16:
                raise MappingError("Gateway returned an invalid NAT-PMP mapping response")
            _, _, _, _, internal, external, granted = struct.unpack("!BBHIHHI", response)
            if internal != port:
                continue  # A late response to a previous request on this socket.
            return external, granted
    raise MappingError(f"Gateway did not confirm {protocol} {port}")


def ensure_mapping(client, protocol, port, lifetime=3600):
    external, granted = exchange(client, protocol, port, lifetime)
    if external != port:
        # NAT-PMP can offer another public port when the requested one is busy.
        # Release only this client's new mapping; never delete another host's.
        exchange(client, protocol, port, 0)
        raise MappingError(f"Gateway offered external port {external} for {protocol} {port}; port preservation is required")
    if granted < 1800:
        raise MappingError(f"Gateway granted too short a lease for {protocol} {port}")


def mappings(min_port, max_port):
    if not 1024 <= min_port <= max_port <= 65535:
        raise MappingError("Invalid TURN media port range")
    return [("UDP", 3478), ("TCP", 3478), ("TCP", 5349)] + [
        ("UDP", port) for port in range(min_port, max_port + 1)
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gateway", required=True)
    parser.add_argument("--lan-address", required=True)
    parser.add_argument("--min-port", type=int, required=True)
    parser.add_argument("--max-port", type=int, required=True)
    args = parser.parse_args()
    try:
        desired = mappings(args.min_port, args.max_port)
        # Separate flows isolate delayed replies. Pace requests to avoid bursts
        # against the consumer gateway's control service.
        for index, (protocol, port) in enumerate(desired, 1):
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                client.bind((args.lan_address, 0))
                client.connect((args.gateway, 5351))
                ensure_mapping(client, protocol, port)
            if index % 64 == 0:
                print(f"Verified {index}/{len(desired)} TURN port mappings", flush=True)
            if index < len(desired):
                time.sleep(0.5)
        print(f"Verified {len(desired)} TURN port mappings to {args.lan_address}; one-hour leases renewed")
        return 0
    except (OSError, MappingError) as error:
        print(f"TURN port mappings: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
