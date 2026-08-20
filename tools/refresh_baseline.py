#!/usr/bin/env python3
"""Regenerate tools/baseline/ from an installed Playnite.

Run this on a Windows box with Playnite installed, then review the diff. It is NOT part
of CI: CI has no Playnite, which is the whole reason the baseline is pinned to a file.

    python tools/refresh_baseline.py --playnite "F:\\Playnite"

What lands in tools/baseline/ is deliberately only *names* - file paths, x:Key names and
PART_* names. None of Playnite's markup is copied, so nothing third-party is redistributed
and the fixture stays small enough to review line by line when Playnite updates.

Regenerate after every Playnite upgrade. A noisy diff here is the signal HYP-213 exists to
produce: it means the theme's ~68 near-verbatim copies of default-theme files may now be
overriding something newer.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

X_NS = "http://schemas.microsoft.com/winfx/2006/xaml"
KEY_ATTR = f"{{{X_NS}}}Key"
NAME_ATTR = f"{{{X_NS}}}Name"
PART_RE = re.compile(r"\bPART_[A-Za-z0-9_]+")

BASELINE = Path(__file__).resolve().parent / "baseline"


def keys_of(path: Path) -> set[str]:
    try:
        tree = ET.parse(path)
    except ET.ParseError:
        return set()
    return {el.get(KEY_ATTR) for el in tree.iter() if el.get(KEY_ATTR)}


def paint_keys_of(path: Path) -> set[str]:
    """Keys whose *element type* is a Color or Brush.

    Matched on the element's local name, not the key's spelling: GridCornerDetailsPanel
    proved that a name-pattern search misses resources that do not say what they are.
    """
    try:
        tree = ET.parse(path)
    except ET.ParseError:
        return set()
    out = set()
    for el in tree.iter():
        key = el.get(KEY_ATTR)
        if key and re.search(r"(Color|Brush)$", el.tag.split("}")[-1]):
            out.add(key)
    return out


def parts_of(path: Path) -> set[str]:
    """PART_* names a template declares.

    Read from the raw text rather than x:Name attributes: a few are referenced from
    TargetName or a trigger rather than declared as x:Name, and for a *baseline* the
    superset is the safer error.
    """
    try:
        text = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return set()
    return set(PART_RE.findall(text))


def collect(root: Path) -> list[Path]:
    return sorted(root.rglob("*.xaml")) if root.is_dir() else []


def write_lines(name: str, lines) -> None:
    path = BASELINE / name
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"  {path.relative_to(BASELINE.parent.parent)}  ({len(lines)} lines)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--playnite", required=True, help=r'Playnite install root, e.g. F:\Playnite')
    args = ap.parse_args()

    root = Path(args.playnite)
    default = root / "Themes" / "Desktop" / "Default"
    templates = root / "Templates" / "Themes"
    localization = root / "Localization"

    if not default.is_dir():
        print(f"FAIL  no default theme at {default}", file=sys.stderr)
        return 1

    # Playnite.DesktopApp.exe reports FileVersion 1.0.0.0, so the real number has to come
    # out of Playnite.dll. Take the HIGHEST match, not the first: the assembly also carries
    # framework strings like "10.0.0" that sort earlier and would silently pin the baseline
    # to a version that never existed.
    version = "unknown"
    dll = root / "Playnite.dll"
    if dll.exists():
        found = re.findall(rb"\b10\.\d{1,3}\.\d{1,3}\b", dll.read_bytes())
        if found:
            version = max(
                (m.decode() for m in set(found)),
                key=lambda v: tuple(int(p) for p in v.split(".")),
            )

    BASELINE.mkdir(parents=True, exist_ok=True)

    default_files = collect(default)
    rel = sorted(f.relative_to(default).as_posix() for f in default_files)

    default_keys: set[str] = set()
    paint: set[str] = set()
    parts: dict[str, set[str]] = {}
    for f in default_files:
        default_keys |= keys_of(f)
        paint |= paint_keys_of(f)
        found_parts = parts_of(f)
        if found_parts:
            parts[f.relative_to(default).as_posix()] = found_parts

    external: set[str] = set()
    for other in (templates, localization):
        for f in collect(other):
            external |= keys_of(f)

    if len(default_keys) < 100 or len(external) < 500:
        print(
            f"FAIL  implausible counts (default={len(default_keys)}, external={len(external)}) "
            "- check --playnite",
            file=sys.stderr,
        )
        return 1

    print(f"Playnite {version}")
    write_lines("VERSION", [
        f"playnite {version}",
        f"default-theme-files {len(rel)}",
        f"default-theme-keys {len(default_keys)}",
        f"external-keys {len(external)}",
        f"paint-keys {len(paint)}",
    ])
    write_lines("default-theme-files.txt", rel)
    write_lines("default-theme-keys.txt", sorted(default_keys))
    write_lines("external-keys.txt", sorted(external))
    write_lines("paint-keys.txt", sorted(paint))
    write_lines("part-names.tsv",
                [f"{f}\t{p}" for f in sorted(parts) for p in sorted(parts[f])])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
