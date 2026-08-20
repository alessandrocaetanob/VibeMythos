#!/usr/bin/env python3
"""Diff source/ against the pinned Playnite default-theme baseline in tools/baseline/.

The theme ships ~68 near-verbatim copies of Playnite's own default-theme files. Each copy
is merged *over* Playnite's, so a copy that falls behind silently overrides whatever
Playnite ships next, and nobody finds out. HYP-203 and HYP-204 were both exactly that: a
template part quietly missing, taking its functionality with it and logging nothing.

Three checks, all name-based - no Playnite install needed, which is why this runs in CI:

  parts    a PART_* the default declares, in a file we also ship, that our copy lacks
           (unless recorded in known-omissions.tsv with a reason)
  paint    a Color/Brush the default defines that we never redefine, so it renders in
           Playnite's stock palette inside a near-black theme (the HYP-202 class)
  files    a .xaml under source/ at a path the default theme does not have, which
           ThemeManager.ApplyTheme will never load (CLAUDE.md hard rule 1)

Regenerate the baseline with tools/refresh_baseline.py after every Playnite upgrade.

Usage:  python3 tools/check_baseline.py [--source source] [--baseline tools/baseline]
Exit code 1 if any check fails.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# stdlib ElementTree, not defusedxml, and deliberately: the only inputs are this repo's
# own files and a fixture generated from a local Playnite install, so there is no
# untrusted XML in play. The CI job depends on this script importing nothing outside the
# stdlib - see the comment on the workflow step.

X_NS = "http://schemas.microsoft.com/winfx/2006/xaml"
KEY_ATTR = f"{{{X_NS}}}Key"
PART_RE = re.compile(r"\bPART_[A-Za-z0-9_]+")
LOCALIZATION_DIR = "Localization"


def read_lines(path: Path) -> list[str]:
    if not path.exists():
        raise SystemExit(f"FAIL  missing baseline file: {path}")
    return [
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]


def theme_keys(source: Path) -> set[str]:
    keys: set[str] = set()
    for path in source.rglob("*.xaml"):
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            continue  # check_well_formed in validate_theme.py owns reporting this
        for el in tree.iter():
            key = el.get(KEY_ATTR)
            if key:
                keys.add(key)
    return keys


def check_parts(source: Path, baseline: Path) -> list[str]:
    declared: dict[str, set[str]] = {}
    for line in read_lines(baseline / "part-names.tsv"):
        rel, part = line.split("\t")
        declared.setdefault(rel, set()).add(part)

    allowed: dict[tuple[str, str], str] = {}
    for line in read_lines(baseline / "known-omissions.tsv"):
        rel, part, reason = line.split("\t", 2)
        allowed[(rel, part)] = reason

    problems = []
    still_missing = set()
    for rel, parts in sorted(declared.items()):
        copy = source / rel
        if not copy.exists():
            continue  # not shipped -> Playnite's own file loads, nothing to drift
        present = set(PART_RE.findall(copy.read_text(encoding="utf-8-sig", errors="replace")))
        for part in sorted(parts - present):
            if (rel, part) in allowed:
                still_missing.add((rel, part))
                continue
            problems.append(
                f"{rel}: PART {part!r} is declared by Playnite's copy but missing from ours "
                f"- restore it, or record it in known-omissions.tsv with a reason"
            )

    # An entry that is no longer missing means the part came back. Harmless at runtime, but
    # left alone the allowlist slowly stops describing reality and stops catching anything.
    for (rel, part) in sorted(set(allowed) - still_missing):
        if (source / rel).exists():
            problems.append(
                f"{rel}: known-omissions.tsv still lists {part!r}, but our copy has it "
                f"- drop the stale line"
            )
    return problems


def check_paint(source: Path, baseline: Path) -> list[str]:
    defined = theme_keys(source)
    return [
        f"{key}: Playnite defines this Color/Brush and the theme never redefines it, so it "
        f"renders in Playnite's stock palette"
        for key in read_lines(baseline / "paint-keys.txt")
        if key not in defined
    ]


def check_files(source: Path, baseline: Path) -> list[str]:
    known = set(read_lines(baseline / "default-theme-files.txt"))
    problems = []
    for path in sorted(source.rglob("*.xaml")):
        rel = path.relative_to(source).as_posix()
        # Localization/*.xaml load through Playnite's own localization path, not the
        # merged-dictionary list, so they are legitimately absent from the default theme.
        if rel.split("/")[0] == LOCALIZATION_DIR:
            continue
        if rel not in known:
            problems.append(
                f"{rel}: no such path in Playnite's default theme, so ApplyTheme will never "
                f"load it (hard rule 1) - the file is dead weight unless it is loaded some "
                f"other way"
            )
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="source", type=Path)
    ap.add_argument("--baseline", default=Path(__file__).resolve().parent / "baseline", type=Path)
    args = ap.parse_args()

    if not args.source.is_dir():
        print(f"FAIL  no source directory at {args.source}")
        return 1

    version = "unknown"
    version_file = args.baseline / "VERSION"
    if version_file.exists():
        for line in version_file.read_text(encoding="utf-8").splitlines():
            if line.startswith("playnite "):
                version = line.split(None, 1)[1]
    print(f"baseline: Playnite {version}\n")

    failed = False
    for name, problems in (
        ("template parts", check_parts(args.source, args.baseline)),
        ("core paint keys", check_paint(args.source, args.baseline)),
        ("claimable file paths", check_files(args.source, args.baseline)),
    ):
        if problems:
            failed = True
            print(f"FAIL  {name} ({len(problems)})")
            for problem in problems:
                print(f"        {problem}")
        else:
            print(f"ok    {name}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
