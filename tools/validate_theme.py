#!/usr/bin/env python3
"""Static checks for the VibeMythos theme.

There is no compiler for a Playnite theme, so these are the only automated safety
net. Everything here is read-only and runs anywhere Python does — the PowerShell
snippets in CLAUDE.md cover the same ground on a Windows dev box.

Checks
  well-formed    every source/**/*.xaml parses as XML
  resources      every {DynamicResource X} / {StaticResource X} resolves to an
                 x:Key defined somewhere in the theme (or is a known Playnite /
                 plugin-supplied key)
  localization   every locale's keys are a subset of en_US, and en_US exists
  thememodifier  every thememodifier.yaml entry resolves to Constants.xaml or
                 Localization/en_US.xaml (section headers excepted)

Usage:  python3 tools/validate_theme.py [--source source]
Exit code 1 if any check fails.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

X_NS = "http://schemas.microsoft.com/winfx/2006/xaml"
KEY_ATTR = f"{{{X_NS}}}Key"

# Keys Playnite itself, or an installed plugin, puts in the merged dictionary.
# A theme is allowed to consume these without defining them.
EXTERNAL_KEY_PREFIXES = (
    "LOC",              # Playnite localization
    "Glyph",            # Playnite glyph set
    "SuccessStory",     # plugin-supplied
    "PlayniteAchievements",
    "HowLongToBeat",
    "ThemeExtras",
    "DuplicateHider",
    "ExtraMetadataLoader",
    "UPS_",
)

# Keys Playnite defines in GlobalResources.xaml or its own default theme, which is
# merged immediately before ours (default/X.xaml -> theme/X.xaml, per file — see
# ThemeManager.ApplyTheme). Consuming these without defining them is legal.
EXTERNAL_KEYS = {
    # GlobalResources.xaml
    "True",
    "False",
    "ObjectToStringConverter",
    "BooleanToVisibilityConverter",
    "InvertedBooleanToVisibilityConverter",
    "NullToVisibilityConverter",
    "InvertedNullToVisibilityConverter",
    "StringNullOrEmptyToVisibilityConverter",
    "IndentConverter",
    "ObjectToJsonConverter",
    "DateTimeToLastPlayedConverter",
    "LongToTimePlayedConverter",
    "ListToStringConverter",
    "NegativeNumberConverter",
    "BrushOpacityConverter",
    # Default theme styles
    "BaseStyle",
    "ScrollViewer",
    "TextBlockBaseStyle",
    "BaseTextBlockStyle",
    # Default theme Constants.xaml:8-9 (20 and 29). The theme consumes these but does
    # not define them, so they resolve only because Playnite's default merges first.
    # Legal, but it does mean the theme does not own its own display size - HYP-211
    # brings them in-theme, after which these entries become harmless no-ops.
    "FontSizeLarger",
    "FontSizeLargest",
}

# NOTE on the two lists above: a hand-maintained allowlist is the weak point of this
# checker. It cannot distinguish "Playnite defines this" from "nobody defines this",
# so a genuinely broken key that happens to match a prefix slips through, and every
# new Playnite release risks a fresh false positive.
#
# The PowerShell version in CLAUDE.md avoids this by reading all four real resource
# roots, but that needs a Playnite install and so cannot run in CI. HYP-168 replaces
# both approaches with a frozen key manifest (~31 KB, the union of the three external
# roots as newline-delimited names): no install needed, nothing third-party
# redistributed, and no guessing by prefix. Until then, treat a pass here as weaker
# evidence than a pass from the PowerShell check.

RESOURCE_RE = re.compile(r"\{\s*(?:Dynamic|Static)Resource\s+([^},\s]+)\s*[,}]")
# `{DynamicResource {x:Static ...}}` and friends are not plain key lookups.
SKIP_RESOURCE_RE = re.compile(r"^\{")
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def strip_comments(text: str) -> str:
    """Blank out XML comments, preserving line count so numbers stay honest.

    Commented-out markup is not loaded, so a stale key inside a comment is not a
    break — reporting it just trains people to ignore the checker.
    """
    return COMMENT_RE.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)


def xaml_files(source: Path) -> list[Path]:
    return sorted(p for p in source.rglob("*.xaml"))


def check_well_formed(files: list[Path]) -> list[str]:
    problems = []
    for path in files:
        try:
            ET.parse(path)
        except ET.ParseError as exc:
            problems.append(f"{path}: {exc}")
    return problems


def defined_keys(files: list[Path]) -> set[str]:
    keys: set[str] = set()
    for path in files:
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            continue
        for el in tree.iter():
            key = el.get(KEY_ATTR)
            if key:
                keys.add(key)
    return keys


def check_resources(files: list[Path], keys: set[str]) -> list[str]:
    problems = []
    for path in files:
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        for lineno, line in enumerate(text.splitlines(), 1):
            for match in RESOURCE_RE.finditer(line):
                name = match.group(1).strip()
                if SKIP_RESOURCE_RE.match(name):
                    continue
                if name in keys or name in EXTERNAL_KEYS:
                    continue
                if name.startswith(EXTERNAL_KEY_PREFIXES):
                    continue
                problems.append(f"{path}:{lineno}: unresolved resource key {name!r}")
    return problems


def locale_keys(path: Path) -> set[str]:
    # Swallow the parse error the way defined_keys does. check_well_formed already owns
    # reporting malformed XAML; without this guard a malformed locale file makes
    # check_localization raise, and the traceback lands *after* the FAIL list and is the
    # first thing a reader sees. The exit code is non-zero either way — this is about the
    # CI log reading like the validator's own report rather than a stack trace.
    try:
        tree = ET.parse(path)
    except ET.ParseError:
        return set()
    return {el.get(KEY_ATTR) for el in tree.iter() if el.get(KEY_ATTR)}


def check_localization(source: Path) -> list[str]:
    loc = source / "Localization"
    if not loc.is_dir():
        return [f"{loc}: missing localization directory"]
    en = loc / "en_US.xaml"
    if not en.exists():
        return [f"{en}: missing — without it Playnite loads no localization at all"]
    problems = []
    en_keys = locale_keys(en)
    for path in sorted(loc.glob("*.xaml")):
        if path.name == "en_US.xaml":
            continue
        extra = locale_keys(path) - en_keys
        if extra:
            problems.append(
                f"{path.name}: {len(extra)} key(s) absent from en_US: "
                + ", ".join(sorted(extra))
            )
    return problems


# thememodifier.yaml holds YAML *sequence* items, not a mapping:
#
#     Constants:
#         - "Accent Colors"                     <- bare string, renders as a section header
#         - AccentIdleBrush: 'Primary Accent'   <- a real entry
#         - SearchBoxWidth(125,200): 'Search Box Width'
#
# This pattern must therefore consume the "- " bullet. The original `^\s{2,}([A-Za-z0-9_]+)`
# could not: after the indent the next character is "-", which is outside the class, and no
# amount of backtracking helps because every shorter prefix of the indent is followed by more
# whitespace. It matched 0 of 51 lines, so check_thememodifier returned [] unconditionally and
# printed "ok" without ever looking anything up.
#
# The optional (?:\([^)]*\))? group carries the numeric-range form. Section headers still
# correctly fail to match, because a double quote is not a word character.
#
# \w rather than [A-Za-z0-9_]: identical for the ASCII keys this file actually holds, and
# on a non-ASCII key it matches rather than skips — so such a key gets *checked* instead of
# silently ignored, which is the safer direction for a validator.
THEMEMODIFIER_ENTRY_RE = re.compile(r"^\s*-\s+(\w+)(?:\([^)]*\))?\s*:")


def check_thememodifier(source: Path, constants_keys: set[str], loc_keys: set[str]) -> list[str]:
    path = source / "thememodifier.yaml"
    if not path.exists():
        return []
    problems = []
    known = constants_keys | loc_keys
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = THEMEMODIFIER_ENTRY_RE.match(line)
        if not match:
            continue
        name = match.group(1)
        if name not in known:
            problems.append(
                f"{path}:{lineno}: {name!r} resolves to neither Constants.xaml "
                "nor Localization/en_US.xaml (renders as a section header)"
            )
    return problems


def report(title: str, problems: list[str]) -> bool:
    if problems:
        print(f"FAIL  {title} ({len(problems)})")
        for problem in problems:
            print(f"        {problem}")
        return False
    print(f"ok    {title}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="source", type=Path)
    args = parser.parse_args()

    source: Path = args.source
    if not source.is_dir():
        print(f"no such directory: {source}", file=sys.stderr)
        return 2

    files = xaml_files(source)
    print(f"{len(files)} XAML files under {source}\n")

    ok = report("well-formed XAML", check_well_formed(files))

    keys = defined_keys(files)
    ok &= report("resource keys resolve", check_resources(files, keys))
    ok &= report("localization parity", check_localization(source))

    constants_keys = defined_keys([source / "Constants.xaml"])
    en = source / "Localization" / "en_US.xaml"
    loc = locale_keys(en) if en.exists() else set()
    ok &= report("thememodifier keys resolve", check_thememodifier(source, constants_keys, loc))

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
