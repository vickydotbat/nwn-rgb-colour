"""E23: `just compile` fails on a broken script and names its file and line."""

import pathlib
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent


def compile_dir(folder):
    return subprocess.run(
        ["just", "compile", str(folder)],
        cwd=REPO, capture_output=True, text=True,
    )


class CompileTest(unittest.TestCase):
    def test_a_syntax_error_fails_and_names_file_and_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = pathlib.Path(tmp)
            (folder / "good.nss").write_text("void main() {}\n")
            (folder / "broken.nss").write_text("void main()\n{\n    int a = ;\n}\n")
            result = compile_dir(folder)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("broken.nss(3)", result.stdout + result.stderr)

    def test_good_scripts_compile(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = pathlib.Path(tmp)
            (folder / "good.nss").write_text(
                'void main() { SetLocalInt(OBJECT_SELF, "a", 1); }\n')
            result = compile_dir(folder)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((folder / "good.ncs").exists())


if __name__ == "__main__":
    unittest.main()
