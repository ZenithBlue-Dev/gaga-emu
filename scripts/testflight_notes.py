#!/usr/bin/env python3
"""Set TestFlight "What to Test" (en-US) for a build from the top entry of docs/testflight-notes.md.

    scripts/testflight_notes.py --check          mint a token and look the app up; changes nothing
    scripts/testflight_notes.py BUILD_NUMBER     set the text for that build

The entry used is the first "## VERSION (BUILD), DATE" section, and its build number must match
BUILD_NUMBER. Credentials come from the environment, else scripts/asc.local.env (untracked).
"""

import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from appstore_metadata import Api, ApiError, DEFAULT_KEY  # noqa: E402

BUNDLE_ID = "com.zenithblue.gagaemu"
NOTES = HERE.parent / "docs" / "testflight-notes.md"
LIMIT = 4000  # App Store Connect caps whatsNew at 4000 characters


def load_env():
    env_file = HERE / "asc.local.env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            key, sep, value = line.partition("=")
            if sep and key.strip() and not key.startswith("#"):
                os.environ.setdefault(key.strip(), value.strip())


def top_entry():
    parts = re.split(r"^## ", NOTES.read_text(), flags=re.M)
    heading, _, body = parts[1].partition("\n")
    build = re.search(r"\((\d+)\)", heading)
    if not build:
        raise SystemExit(f"no build number in heading: {heading}")
    return build.group(1), body.strip()


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    load_env()
    api = Api(os.environ.get("ASC_KEY_ID", "HDY587QW5K"), os.environ["ASC_ISSUER_ID"],
              os.path.expanduser(os.environ.get("ASC_API_KEY_PATH", str(DEFAULT_KEY))))
    apps = api.get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit(f"no App Store Connect app for {BUNDLE_ID}")
    app_id = apps[0]["id"]
    if sys.argv[1] == "--check":
        print("credentials ok, app", BUNDLE_ID, "found")
        return

    number = sys.argv[1]
    entry_build, text = top_entry()
    if entry_build != number:
        raise SystemExit(f"top entry of {NOTES.name} is {entry_build}, not {number}")
    if len(text) > LIMIT:
        raise SystemExit(f"notes are {len(text)} characters; the limit is {LIMIT}")
    found = api.get("/v1/builds", **{"filter[app]": app_id, "filter[version]": number,
                                     "sort": "-uploadedDate", "limit": "1"})["data"]
    if not found:
        raise SystemExit(f"build {number} not found in App Store Connect")
    build_id = found[0]["id"]
    locs = api.get(f"/v1/builds/{build_id}/betaBuildLocalizations", limit="50")["data"]
    en = next((l for l in locs if l["attributes"]["locale"] == "en-US"), None)
    if en:
        api.patch("betaBuildLocalizations", en["id"], {"whatsNew": text})
    else:
        api.post("betaBuildLocalizations", {"locale": "en-US", "whatsNew": text},
                 {"build": {"data": {"type": "builds", "id": build_id}}})
    print(f"What to Test set for build {number} ({len(text)} chars, {'updated' if en else 'created'})")


if __name__ == "__main__":
    try:
        main()
    except ApiError as error:
        raise SystemExit(str(error))
