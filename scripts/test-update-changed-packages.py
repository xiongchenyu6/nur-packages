#!/usr/bin/env python3
"""Exercise updater selection and failure handling without downloading packages."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("update-changed-packages.sh").resolve()
OLD = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
NEW = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nur-update-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "_sources").mkdir()
        (self.root / "bin").mkdir()
        self.write_sources({})
        self.git("init", "-q")
        self.fake_nix = self.root / "bin/nix"
        self.fake_nix.write_text("""#!/usr/bin/env bash
set -eu
if [[ $1 == eval ]]; then
  printf '%s' "${TEST_SUPPORT:-supported}"
  exit 0
fi
echo build >> builds.log
if [[ ${TEST_BUILD_ERROR:-0} == 1 ]]; then
  echo 'error: PHP patch failed' >&2
  exit 1
fi
if [[ ${TEST_HASH_MISMATCH:-0} == 1 ]] && rg -q --fixed-strings "$TEST_OLD_HASH" pkgs; then
  echo "error: hash mismatch in fixed-output derivation composer-vendor:" >&2
  echo "  specified: $TEST_OLD_HASH" >&2
  echo "        got: $TEST_NEW_HASH" >&2
  exit 1
fi
""")
        self.fake_nix.chmod(0o755)

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args],
                              check=True, capture_output=True, text=True)

    def commit(self):
        self.git("add", "_sources", "pkgs")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "commit", "-qm", "fixture")

    def package(self, name="hashtopolis-server", source="hashtopolis-server"):
        path = self.root / "pkgs" / name / "package.nix"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'sources.{source} // {{ vendorHash = "{OLD}"; }}\n')
        return path

    def write_sources(self, data):
        (self.root / "_sources/generated.json").write_text(json.dumps(data))

    def run_update(self, **extra):
        env = os.environ | {"PATH": str(self.root / "bin") + ":" + os.environ["PATH"],
                            "TEST_OLD_HASH": OLD, "TEST_NEW_HASH": NEW} | extra
        return subprocess.run(["bash", str(SCRIPT)], cwd=self.root,
                              env=env, capture_output=True, text=True)

    def source_change(self):
        package = self.package()
        self.write_sources({"hashtopolis-server": {"version": "v1.0.0"}})
        self.commit()
        self.write_sources({"hashtopolis-server": {"version": "v1.0.1"}})
        return package

    def test_composer_hash_refresh_retries(self):
        package = self.source_change()
        result = self.run_update(TEST_HASH_MISMATCH="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(NEW, package.read_text())
        self.assertEqual(len((self.root / "builds.log").read_text().splitlines()), 2)

    def test_gate_does_not_rewrite_hashes(self):
        package = self.source_change()
        result = self.run_update(TEST_HASH_MISMATCH="1", UPDATE_FIX_HASHES="0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(OLD, package.read_text())

    def test_build_error_remains_failure(self):
        package = self.source_change()
        result = self.run_update(TEST_BUILD_ERROR="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("PHP patch failed", result.stderr)
        self.assertIn(OLD, package.read_text())

    def test_unmapped_source_fails(self):
        self.package()
        self.commit()
        self.write_sources({"unmapped": {"version": "1"}})
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("has no build target", result.stderr)

    def test_source_name_prefix_is_not_a_mapping(self):
        self.package(source="foo-other")
        self.commit()
        self.write_sources({"foo": {"version": "1"}})
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)

    def test_package_change_without_source_change(self):
        package = self.package()
        self.commit()
        package.write_text(package.read_text() + "# package fix\n")
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Built hashtopolis-server", result.stdout)

    def test_unsupported_platform_is_explicit(self):
        self.source_change()
        result = self.run_update(TEST_SUPPORT="unsupported")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("meta.platforms excludes", result.stdout)
        self.assertFalse((self.root / "builds.log").exists())

    def test_nested_postgres_extensions_map_both_versions(self):
        extensions = {
            "index_advisor": "index-advisor",
            "pg_plan_filter": "pg-plan-filter",
            "pg_hashids": "pg-hashids",
            "pg_ecdsa_verify": "pg-ecdsa-verify",
        }
        for extension, source in extensions.items():
            self.package("pg-extensions/" + extension, source)
        self.commit()
        self.write_sources({source: {"version": "1"} for source in extensions.values()})
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for extension in extensions:
            for version in (17, 18):
                self.assertIn(f"Built postgresql{version}Packages.{extension}", result.stdout)

    def test_no_changes_is_a_successful_noop(self):
        self.package()
        self.commit()
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.root / "builds.log").exists())

    def test_reports_every_failed_package(self):
        a = self.package("a", "a")
        b = self.package("b", "b")
        self.commit()
        for path in (a, b):
            path.write_text(path.read_text() + "# changed\n")
        result = self.run_update(TEST_BUILD_ERROR="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Building a", result.stdout)
        self.assertIn("Building b", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
