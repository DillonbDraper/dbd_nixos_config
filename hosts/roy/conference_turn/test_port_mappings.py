import base64
import hashlib
import hmac
import socket
import struct
import unittest
from unittest.mock import patch

from port_mappings import MappingError, ensure_mapping, mappings
from test_credentials import credentials


def reply(port, external=None, opcode=1, status=0, lifetime=3600):
    return struct.pack("!BBHIHHI", 0, opcode + 128, status, 1234, port,
                       port if external is None else external, lifetime)


class Gateway:
    def __init__(self, replies):
        self.replies = iter(replies)
        self.requests = []

    def send(self, request):
        self.requests.append(struct.unpack("!BBHHHI", request))

    def settimeout(self, _timeout):
        pass

    def recv(self, _length):
        response = next(self.replies)
        if isinstance(response, Exception):
            raise response
        return response


class PortMappingTest(unittest.TestCase):
    def test_exact_scope_is_three_listeners_and_configured_media_range(self):
        desired = mappings(49152, 49407)
        self.assertEqual(len(desired), 259)
        self.assertEqual(desired[:3], [("UDP", 3478), ("TCP", 3478), ("TCP", 5349)])
        self.assertEqual(desired[3:], [("UDP", port) for port in range(49152, 49408)])

    def test_preserves_port_numbers_for_both_protocols(self):
        for protocol, opcode in (("UDP", 1), ("TCP", 2)):
            gateway = Gateway([reply(49152, opcode=opcode)])
            ensure_mapping(gateway, protocol, 49152)
            self.assertEqual(gateway.requests, [(0, opcode, 0, 49152, 49152, 3600)])

    def test_late_reply_cannot_confirm_the_next_port(self):
        gateway = Gateway([reply(49151), reply(49152)])
        ensure_mapping(gateway, "UDP", 49152)
        self.assertEqual(len(gateway.requests), 1)

    def test_timeout_retries_then_fails(self):
        gateway = Gateway([socket.timeout()] * 4)
        with self.assertRaises(MappingError):
            ensure_mapping(gateway, "UDP", 49152)
        self.assertEqual(len(gateway.requests), 4)

    def test_transient_gateway_failure_can_recover_without_a_different_port(self):
        gateway = Gateway([reply(49152, status=3), reply(49152)])
        with patch("port_mappings.time.sleep"):
            ensure_mapping(gateway, "UDP", 49152)
        self.assertEqual([request[3:5] for request in gateway.requests], [(49152, 49152)] * 2)

    def test_alternative_port_is_released_and_refused(self):
        gateway = Gateway([reply(49152, external=50000), reply(49152, external=0, lifetime=0)])
        with self.assertRaisesRegex(MappingError, "port preservation"):
            ensure_mapping(gateway, "UDP", 49152)
        self.assertEqual(gateway.requests[-1][-1], 0)

    def test_gateway_errors_bad_leases_and_invalid_ranges_fail(self):
        for response in (reply(49152, status=2), reply(49152, lifetime=60), b'\x00\x81\x00\x00\x00\x00\x00\x00'):
            with self.subTest(response=response), self.assertRaises(MappingError):
                ensure_mapping(Gateway([response]), "UDP", 49152)
        for low, high in ((0, 1), (50000, 49999), (49152, 65536)):
            with self.assertRaises(MappingError):
                mappings(low, high)

    def test_operator_credentials_are_signed_and_expire_after_fifteen_minutes(self):
        secret = b'a-separate-test-secret-at-least-32-bytes'
        username, password, expiry = credentials(secret, 1000)
        self.assertEqual(expiry, 1900)
        self.assertTrue(username.startswith("1900:operator-"))
        expected = base64.b64encode(hmac.new(secret, username.encode(), hashlib.sha1).digest()).decode()
        self.assertEqual(password, expected)
        with self.assertRaises(ValueError):
            credentials(b'too-short', 1000)


if __name__ == "__main__":
    unittest.main()
