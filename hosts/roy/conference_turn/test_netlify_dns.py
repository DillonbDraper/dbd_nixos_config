import io
from pathlib import Path
import tempfile
import unittest
import urllib.error

from netlify_dns import Netlify, NoRedirect, TOKEN_PLACEHOLDER, UpdateError, discover_address, reconcile, token_from


class FakeAPI:
    def __init__(self, records=None, create_error=False, bad_created_record=False, zones=None):
        self.records = records or []
        self.zones = zones if zones is not None else [{"id": "zone-id", "name": "whatgrabsme_org", "domain": "whatgrabsme.org"}]
        self.calls = []
        self.create_error = create_error
        self.bad_created_record = bad_created_record

    def request(self, method, path, data=None):
        self.calls.append((method, path, data))
        if method == "GET":
            if path == "/dns_zones":
                return self.zones
            if path == "/dns_zones/zone-id/dns_records":
                return self.records
            raise AssertionError(f"Unexpected DNS lookup: {path}")
        if method == "POST":
            if self.create_error:
                raise UpdateError("Creation failed")
            return {} if self.bad_created_record else {"id": "new", **data}


def record(identity, value, kind="A", hostname="turn.whatgrabsme.org"):
    return {"id": identity, "hostname": hostname, "type": kind, "value": value}


class DNSUpdaterTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def run_update(self, api, address="8.8.8.8", hostname="turn.whatgrabsme.org"):
        return reconcile(api, "whatgrabsme.org", hostname, address, "192.168.1.54", self.directory)

    def test_bootstrap_creates_dns_and_restricted_atomic_mapping(self):
        api = FakeAPI()
        self.assertTrue(self.run_update(api))
        path = self.directory / "external-ip.conf"
        self.assertEqual(path.read_text(), "external-ip=8.8.8.8/192.168.1.54\n")
        self.assertEqual(path.stat().st_mode & 0o777, 0o640)
        self.assertTrue((self.directory / "restart-required").exists())
        self.assertEqual(api.calls[-1][2]["ttl"], 300)

    def test_domain_is_resolved_to_zone_id_before_accessing_records(self):
        api = FakeAPI(zones=[
            {"id": "unrelated-id", "name": "example_org", "domain": "example.org"},
            {"id": "zone-id", "name": "whatgrabsme_org", "domain": "whatgrabsme.org"},
        ])
        self.run_update(api)
        self.assertEqual([call[1] for call in api.calls], [
            "/dns_zones", "/dns_zones/zone-id/dns_records", "/dns_zones/zone-id/dns_records",
        ])

    def test_missing_or_ambiguous_zones_cannot_modify_dns_or_mapping(self):
        for zones in ([], [{"id": "other", "domain": "example.org"}],
                      [{"domain": "whatgrabsme.org"}],
                      [{"id": "one", "domain": "whatgrabsme.org"}, {"id": "two", "domain": "whatgrabsme.org"}],
                      {"id": "zone-id", "domain": "whatgrabsme.org"}):
            with self.subTest(zones=zones):
                api = FakeAPI(zones=zones)
                with self.assertRaises(UpdateError):
                    self.run_update(api)
                self.assertEqual(api.calls, [("GET", "/dns_zones", None)])
                self.assertFalse((self.directory / "external-ip.conf").exists())

    def test_unchanged_address_does_not_rewrite_dns_or_restart(self):
        self.run_update(FakeAPI())
        (self.directory / "restart-required").unlink()
        api = FakeAPI([record("existing", "8.8.8.8")])
        self.assertFalse(self.run_update(api))
        self.assertEqual([call[0] for call in api.calls], ["GET", "GET"])
        self.assertFalse((self.directory / "restart-required").exists())

    def test_replacement_is_created_before_old_records_are_removed(self):
        api = FakeAPI([
            record("old", "1.1.1.1"),
            record("website", "1.1.1.1", hostname="jellyfin.whatgrabsme.org"),
            record("txt", "acme-value", kind="TXT", hostname="_acme-challenge.turn.whatgrabsme.org"),
        ])
        self.run_update(api)
        self.assertEqual([call[0] for call in api.calls], ["GET", "GET", "POST", "DELETE"])
        self.assertTrue(api.calls[-1][1].endswith("/old"))

    def test_retry_reuses_confirmed_replacement_after_partial_update(self):
        api = FakeAPI([record("old", "1.1.1.1"), record("new", "8.8.8.8")])
        self.run_update(api)
        self.assertEqual([call[0] for call in api.calls], ["GET", "GET", "DELETE"])

    def test_creation_failure_keeps_old_dns_and_local_mapping(self):
        self.run_update(FakeAPI(), "1.1.1.1")
        for api in (FakeAPI([record("old", "1.1.1.1")], create_error=True),
                    FakeAPI([record("old", "1.1.1.1")], bad_created_record=True)):
            with self.assertRaises(UpdateError):
                self.run_update(api)
            self.assertNotIn("DELETE", [call[0] for call in api.calls])
            self.assertIn("external-ip=1.1.1.1/", (self.directory / "external-ip.conf").read_text())

    def test_conflicting_record_types_are_preserved_and_refused(self):
        for kind in ("CNAME", "AAAA"):
            api = FakeAPI([record("other", "elsewhere", kind=kind)])
            with self.assertRaises(UpdateError):
                self.run_update(api)
            self.assertEqual([call[0] for call in api.calls], ["GET", "GET"])

    def test_private_invalid_addresses_and_outside_hostnames_cannot_be_published(self):
        for address, hostname in (("127.0.0.1", "turn.whatgrabsme.org"),
                                  ("100.64.1.2", "turn.whatgrabsme.org"),
                                  ("not-an-ip", "turn.whatgrabsme.org"),
                                  ("8.8.8.8", "whatgrabsme.org"),
                                  ("8.8.8.8", "other.example.org")):
            api = FakeAPI()
            with self.assertRaises(UpdateError):
                self.run_update(api, address, hostname)
            self.assertEqual(api.calls, [])

    def test_missing_and_placeholder_tokens_wait_for_operator_setup(self):
        path = self.directory / "token"
        self.assertIsNone(token_from(path))
        for value in ("", TOKEN_PLACEHOLDER):
            path.write_text(value)
            self.assertIsNone(token_from(path))
        path.write_text("a-valid-test-token\n")
        self.assertEqual(token_from(path), "a-valid-test-token")

    def test_netlify_errors_do_not_include_credentials_or_response_body(self):
        class FailedOpener:
            def open(self, request, timeout):
                raise urllib.error.HTTPError(request.full_url, 401, "unauthorized", {}, io.BytesIO(b"private-response"))
        api = Netlify("private-token", FailedOpener())
        with self.assertRaisesRegex(UpdateError, r"HTTP 401") as error:
            api.request("GET", "/dns_zones/whatgrabsme.org")
        self.assertNotIn("private-token", str(error.exception))
        self.assertNotIn("private-response", str(error.exception))
        self.assertIn("GET /dns_zones/whatgrabsme.org", str(error.exception))

    def test_http_redirects_are_not_followed_with_api_credentials(self):
        with self.assertRaises(UpdateError):
            NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://other.example/")

    def test_public_discovery_falls_back_without_accepting_private_addresses(self):
        class Opener:
            def __init__(self):
                self.results = iter([b"192.168.1.1", b"8.8.8.8\n"])
            def open(self, url, timeout):
                return io.BytesIO(next(self.results))
        self.assertEqual(discover_address(Opener()), "8.8.8.8")


if __name__ == "__main__":
    unittest.main()
