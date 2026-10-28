"""Exercise Nix tool integration without registering an agent or running a task."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from htpclient.binarydownload import BinaryDownload
from htpclient.files import Files
from htpclient.helpers import retrieve_binary


class NativeToolsTest(unittest.TestCase):
    def setUp(self):
        self.previous = Path.cwd()
        self.temp = tempfile.TemporaryDirectory(prefix="agent-tools-")
        os.chdir(self.temp.name)
        Path("files").mkdir()
        self.config = {
            "url": "https://example.invalid/api/server.php",
            "token": "test-token",
            "files-path": "files",
            "crackers-path": "crackers",
            "multicast": False,
            "use-native-hashcat": True,
        }

    def tearDown(self):
        os.chdir(self.previous)
        self.temp.cleanup()

    def save_config(self):
        Path("config.json").write_text(json.dumps(self.config))

    def test_system_7z_precedes_stale_download_and_skips_download(self):
        self.save_config()
        Path("7zr").write_text("old downloaded executable")
        self.assertEqual(retrieve_binary("7zr"), shutil.which("7z"))
        with patch("htpclient.binarydownload.JsonRequest") as request:
            BinaryDownload(SimpleNamespace(disable_update=True)).run()
            request.assert_not_called()

    def test_native_hashcat_preserves_flags_and_does_not_download(self):
        native = Path("native hashcat").absolute()
        native.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
        native.chmod(0o755)
        self.config["native-hashcat-path"] = str(native)
        self.save_config()
        answer = {"response": "SUCCESS", "url": "", "executable": "hashcat.bin"}
        with patch("htpclient.binarydownload.JsonRequest") as request, patch("htpclient.binarydownload.Download.download") as download:
            request.return_value.execute.return_value = answer
            agent = BinaryDownload(SimpleNamespace(disable_update=True))
            self.assertTrue(agent.check_version(42))
            self.assertTrue(agent.check_version(42))  # refresh an existing link
            download.assert_not_called()
        binary = Path("crackers/42/hashcat.bin")
        self.assertTrue(binary.is_symlink())
        self.assertEqual(binary.resolve(), native)
        self.assertEqual(agent.get_version()["executable"], binary.name)
        result = subprocess.check_output([str(binary.absolute()), "--version", "-D", "1"], text=True)
        self.assertEqual(result.splitlines(), ["--version", "-D", "1"])

    def test_missing_native_binary_does_not_replace_existing_binary(self):
        self.config["native-hashcat-path"] = "/nonexistent/hashcat"
        self.save_config()
        binary = Path("crackers/42/hashcat.bin")
        binary.parent.mkdir(parents=True)
        binary.write_text("existing")
        with patch("htpclient.binarydownload.JsonRequest") as request:
            request.return_value.execute.return_value = {"response": "SUCCESS", "url": "", "executable": "hashcat.bin"}
            self.assertFalse(BinaryDownload(SimpleNamespace(disable_update=True)).check_version(42))
        self.assertEqual(binary.read_text(), "existing")

    def test_wordlist_archive_extraction_uses_real_system_7z(self):
        self.save_config()
        Path("wordlist.txt").write_text("alpha\nbeta\n")
        subprocess.run(["7z", "a", "wordlist.7z", "wordlist.txt"], check=True, stdout=subprocess.DEVNULL)
        archive = Path("wordlist.7z").absolute()
        answer = {"response": "SUCCESS", "url": "archive", "filesize": archive.stat().st_size}
        with patch("htpclient.files.JsonRequest") as request, patch("htpclient.files.Download.download", side_effect=lambda url, target: shutil.copyfile(archive, target)):
            request.return_value.execute.return_value = answer
            self.assertTrue(Files().check_files(["wordlist.7z"], 123))
        self.assertEqual(Path("files/wordlist.txt").read_text(), "alpha\nbeta\n")
        self.assertFalse(Path("7zr").exists())


if __name__ == "__main__":
    unittest.main()
