#!/usr/bin/env python3
"""Regenerates play_by_play_phrases.dart from play_by_play_phrases.toml.

Run this after hand-editing the TOML (2026-08-17, a direct GM ask: "put
into a TOML, so I can go through and edit/add my own stuff... if it's
more efficient to pull it into the code, not a file, we can do that
later after I've hand edited it" -- the GM was fine either way, and a
runtime TOML-parsing package felt like overkill for one dev-only lab
screen's content, so this script does the pull-into-code conversion
instead). No third-party dependencies -- stdlib `tomllib` only.

Usage: python3 tool/generate_play_by_play_phrases.py
"""

import pathlib
import tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOML_PATH = ROOT / "lib/features/match/presentation/play_by_play_phrases.toml"
DART_PATH = ROOT / "lib/features/match/presentation/play_by_play_phrases.dart"


def dart_string(s: str) -> str:
    escaped = s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    return f"'{escaped}'"


def main() -> None:
    with TOML_PATH.open("rb") as f:
        data = tomllib.load(f)

    total = sum(len(section["phrases"]) for section in data.values())

    lines = [
        "// GENERATED FILE -- do not hand-edit.",
        "//",
        "// Produced by tool/generate_play_by_play_phrases.py from",
        "// play_by_play_phrases.toml. Edit the TOML (that's the GM's own",
        "// hand-editable copy), then re-run the script to refresh this file:",
        "//   python3 tool/generate_play_by_play_phrases.py",
        "",
        f"// {total} phrases across {len(data)} categories.",
        "const Map<String, List<String>> kPlayByPlayPhrases = {",
    ]
    for category, section in data.items():
        lines.append(f"  {dart_string(category)}: [")
        for phrase in section["phrases"]:
            lines.append(f"    {dart_string(phrase)},")
        lines.append("  ],")
    lines.append("};")
    lines.append("")

    DART_PATH.write_text("\n".join(lines))
    print(f"Wrote {DART_PATH.relative_to(ROOT)} -- {total} phrases, {len(data)} categories.")


if __name__ == "__main__":
    main()
