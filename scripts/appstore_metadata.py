#!/usr/bin/env python3
"""Checks the App Store listing in AppStore/ and pushes it to App Store Connect.

    scripts/appstore_metadata.py --check     validate the files only (no network)
    scripts/appstore_metadata.py --push      validate, then update App Store Connect

--push reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_API_KEY_PATH (the .p8 file) from the environment
(or --key-id / --issuer-id / --key-path). Default key path is the ZenithBlue AuthKey.
It only reads and updates metadata: it never creates or submits a review submission.
Standard library only; the ES256 token is signed with the openssl CLI.
Adapted from samba-s3 scripts/ios/appstore_metadata.py.
"""

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "AppStore"
API = "https://api.appstoreconnect.apple.com"
DEFAULT_KEY = Path.home() / ".appstoreconnect/private_keys/AuthKey_HDY587QW5K.p8"

# App Store Connect field limits (characters).
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "description": 4000,
    "keywords": 100,
    "review_notes": 4000,
}
REQUIRED = ["name", "subtitle", "description", "keywords", "support_url", "privacy_url", "copyright"]
# Trademarks and claims the listing must not use (App Review 4.7).
FORBIDDEN = [r"play\s*station", r"\bps\s*[1-5]\b", r"\bps\b", r"\bsony\b", r"\bpsn\b",
             r"\bnintendo\b", r"\bsega\b", r"\bxbox\b", r"\batari\b",
             r"\bbios\s+download", r"\bdownload\s+(games|roms|firmware)\b", r"\biso\s+download"]
# Screenshot folders (AppStore/screenshots/<locale>/<folder>/*.png) and their display types.
# The 6.7" slot takes the 6.9" sizes (1320 x 2868). The 6.1" slot takes the 6.3" sizes (1206 x 2622), Apple's
# required "Dynamic Island (medium display)" class. scripts/make_screenshots.swift writes both folders.
SCREENSHOT_TYPES = {"iphone-6.9": "APP_IPHONE_67", "iphone-6.3": "APP_IPHONE_61"}
SCREENSHOT_SIZES = {"APP_IPHONE_67": {(1320, 2868), (2868, 1320), (1290, 2796), (2796, 1290)},
                    "APP_IPHONE_61": {(1206, 2622), (2622, 1206), (1179, 2556), (2556, 1179)}}
MIN_SCREENSHOTS = {"APP_IPHONE_67": 3, "APP_IPHONE_61": 3}
# Guideline 4.7: the listing must say no games or firmware ship with the app.
REQUIRED_PHRASES = {"description": [r"does not include", r"legally", r"roms?", r"bios"]}


def load_listing(locale):
    listing = {}
    for path in sorted((ROOT / "metadata" / locale).glob("*.txt")):
        listing[path.stem] = path.read_text(encoding="utf-8").strip()
    return listing


def png_info(path):
    """(width, height, color type) from the IHDR chunk."""
    header = path.read_bytes()[:26]
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        return 0, 0, -1
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big"), header[25]


def check(listing, app):
    errors = []
    for field in REQUIRED:
        if not listing.get(field):
            errors.append(f"{field} is empty")
    for field, limit in LIMITS.items():
        if len(listing.get(field, "")) > limit:
            errors.append(f"{field} has {len(listing[field])} characters, the limit is {limit}")
    for field, text in listing.items():
        if field == "review_notes":
            continue  # Notes to the reviewer may name ROMs and BIOS.
        for pattern in FORBIDDEN:
            if re.search(pattern, text, re.IGNORECASE):
                errors.append(f"{field} matches the forbidden pattern {pattern!r}")
    for field, patterns in REQUIRED_PHRASES.items():
        for pattern in patterns:
            if not re.search(pattern, listing.get(field, ""), re.IGNORECASE):
                errors.append(f"{field} must contain {pattern!r}")
    for field in ("support_url", "marketing_url", "privacy_url"):
        value = listing.get(field, "")
        if value and not value.startswith("https://"):
            errors.append(f"{field} must be an https URL")
    keywords = [k.strip().lower() for k in listing.get("keywords", "").split(",")]
    if len(keywords) != len(set(keywords)) or "" in keywords:
        errors.append("keywords repeat or contain an empty entry")
    for word in listing.get("name", "").lower().split():
        if word in keywords:
            errors.append(f"keyword {word!r} repeats the app name")
    shots = screenshot_files(app["locale"])
    for kind, minimum in MIN_SCREENSHOTS.items():
        count = len(shots.get(kind, []))
        if not minimum <= count <= 10:
            errors.append(f"{kind}: {count} screenshots, need {minimum} to 10")
    for kind, files in shots.items():
        for path in files:
            width, height, color = png_info(path)
            if (width, height) not in SCREENSHOT_SIZES[kind]:
                errors.append(f"{path.name}: {width} x {height} is not a {kind} size")
            if color not in (2,):  # 2 = RGB; App Store Connect rejects alpha
                errors.append(f"{path.name}: must be an RGB PNG without alpha (color type {color})")
    # shortcut: no AppIcon asset in this repo yet, so the 1024 icon check is skipped; add it when an icon exists
    if app.get("contentRightsDeclaration") not in ("DOES_NOT_USE_THIRD_PARTY_CONTENT",
                                                   "USES_THIRD_PARTY_CONTENT"):
        errors.append("app.json has no valid contentRightsDeclaration")
    if not isinstance(app.get("ageRatingDeclaration"), dict):
        errors.append("app.json has no ageRatingDeclaration")
    if app.get("ITSAppUsesNonExemptEncryption") is not False:
        errors.append("app.json must set ITSAppUsesNonExemptEncryption to false")
    return errors


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """ECDSA signature: DER SEQUENCE(INTEGER r, INTEGER s) -> the 64-byte r || s JWS wants."""
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        if der[i] != 2:
            raise ValueError("bad DER signature")
        n = der[i + 1]
        out += der[i + 2:i + 2 + n].lstrip(b"\0").rjust(32, b"\0")
        i += 2 + n
    return out


assert der_to_raw(bytes([0x30, 6, 2, 1, 5, 2, 1, 7])) == b"\0" * 31 + b"\5" + b"\0" * 31 + b"\7"


def token(key_id, issuer_id, key_path):
    now = int(time.time())
    head = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    body = b64url(json.dumps({"iss": issuer_id, "iat": now, "exp": now + 15 * 60,
                              "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{head}.{body}"
    signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                               input=signing_input.encode(), capture_output=True, check=True).stdout
    return f"{signing_input}.{b64url(der_to_raw(signature))}"


class ApiError(Exception):
    pass


class Api:
    def __init__(self, key_id, issuer_id, key_path):
        self.auth = "Bearer " + token(key_id, issuer_id, key_path)

    def call(self, method, path, body=None, query=None):
        # Metadata only: nothing here may submit the app for review.
        if "submission" in path.lower():
            raise SystemExit(f"refusing to call {path}: review submissions are out of scope")
        url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", self.auth)
        request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                text = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")
            try:
                detail = "; ".join(
                    f"{e.get('code')}: {e.get('detail') or e.get('title')}"
                    + (f" ({e['source'].get('pointer')})" if e.get("source") else "")
                    for e in json.loads(detail).get("errors", []))
            except ValueError:
                pass
            raise ApiError(f"{method} {path} failed with {error.code}: {detail}") from None
        return json.loads(text) if text else {}

    def get(self, path, **query):
        return self.call("GET", path, query=query or None)

    def patch(self, kind, ident, attributes=None, relationships=None):
        data = {"type": kind, "id": ident}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = relationships
        return self.call("PATCH", f"/v1/{kind}/{ident}", {"data": data})

    def post(self, kind, attributes, relationships):
        return self.call("POST", f"/v1/{kind}",
                         {"data": {"type": kind, "attributes": attributes, "relationships": relationships}})


def only_set(values):
    return {k: v for k, v in values.items() if v}


def screenshot_files(locale):
    folders = {}
    for folder, kind in SCREENSHOT_TYPES.items():
        files = sorted((ROOT / "screenshots" / locale / folder).glob("*.png"))
        if files:
            folders[kind] = files
    return folders


def upload_screenshots(api, localization_id, kind, files):
    """Replaces the screenshots of one display type, unless they are already these files."""
    sets = api.get(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")["data"]
    shot_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == kind), None)
    checksums = [hashlib.md5(f.read_bytes()).hexdigest() for f in files]
    if shot_set:
        current = api.get(f"/v1/appScreenshotSets/{shot_set['id']}/appScreenshots")["data"]
        if [c["attributes"].get("sourceFileChecksum") for c in current] == checksums:
            return "unchanged"
        for shot in current:
            api.call("DELETE", f"/v1/appScreenshots/{shot['id']}")
    else:
        shot_set = api.post("appScreenshotSets", {"screenshotDisplayType": kind}, {
            "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations",
                                                     "id": localization_id}}})["data"]
    for path, checksum in zip(files, checksums):
        data = path.read_bytes()
        shot = api.post("appScreenshots", {"fileName": path.name, "fileSize": len(data)}, {
            "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": shot_set["id"]}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            part = data[op["offset"]:op["offset"] + op["length"]]
            request = urllib.request.Request(op["url"], data=part, method=op["method"])
            for header in op.get("requestHeaders") or []:
                request.add_header(header["name"], header["value"])
            with urllib.request.urlopen(request, timeout=120):
                pass
        api.patch("appScreenshots", shot["id"], {"uploaded": True, "sourceFileChecksum": checksum})
    return f"{len(files)} uploaded"


def push(listing, app, credentials):
    api = Api(*credentials)
    failures = []

    def step(name, action):
        try:
            action()
            print(f"updated: {name}")
        except ApiError as error:
            failures.append(f"{name}: {error}")
            print(f"FAILED: {name}: {error}")

    apps = api.get("/v1/apps", **{"filter[bundleId]": app["bundleId"]})["data"]
    if not apps:
        raise SystemExit(f"no App Store Connect app record for {app['bundleId']}: create it in the "
                         "App Store Connect website first (the API cannot create apps)")
    app_id = apps[0]["id"]
    print(f"app: {apps[0]['attributes'].get('name')} ({app['bundleId']})")

    infos = api.get(f"/v1/apps/{app_id}/appInfos")["data"]
    live = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE"}
    info = next((i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState"))
                 not in live), infos[0])

    def app_info_localization():
        locs = api.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
        loc = next((l for l in locs if l["attributes"]["locale"] == app["locale"]), None)
        attributes = only_set({"name": listing.get("name"), "subtitle": listing.get("subtitle"),
                               "privacyPolicyUrl": listing.get("privacy_url")})
        if loc:
            api.patch("appInfoLocalizations", loc["id"], attributes)
        else:
            api.post("appInfoLocalizations", {"locale": app["locale"], **attributes},
                     {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}})

    def categories():
        relationships = {"primaryCategory": {"data": {"type": "appCategories", "id": app["primaryCategory"]}}}
        secondary = app.get("secondaryCategory")
        relationships["secondaryCategory"] = {
            "data": {"type": "appCategories", "id": secondary} if secondary else None}
        api.patch("appInfos", info["id"], relationships=relationships)

    def age_rating():
        declaration = api.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
        known = declaration.get("attributes", {})
        wanted = app["ageRatingDeclaration"]
        unknown = sorted(set(wanted) - set(known))
        missing = sorted(k for k in known if k not in wanted and known[k] is None)
        if unknown:
            print(f"  age rating: not in the API, skipped: {', '.join(unknown)}")
        if missing:
            print(f"  age rating: unanswered questions to add to app.json: {', '.join(missing)}")
        api.patch("ageRatingDeclarations", declaration["id"],
                  {k: v for k, v in wanted.items() if k in known})

    def content_rights():
        api.patch("apps", app_id, {"contentRightsDeclaration": app["contentRightsDeclaration"]})

    step("app info localization (name, subtitle, privacy policy URL)", app_info_localization)
    step("content rights", content_rights)
    step("categories", categories)
    step("age rating", age_rating)

    versions = api.get(f"/v1/apps/{app_id}/appStoreVersions",
                       **{"filter[platform]": app["platform"], "filter[versionString]": app["versionString"]})["data"]
    if not versions:
        try:
            versions = [api.post("appStoreVersions",
                                 {"platform": app["platform"], "versionString": app["versionString"]},
                                 {"app": {"data": {"type": "apps", "id": app_id}}})["data"]]
            print(f"created: {app['platform']} version {app['versionString']}")
        except ApiError as error:
            failures.append(f"create version {app['versionString']}: {error}")
    if versions:
        version = versions[0]
        print(f"version: {app['versionString']} ({version['attributes'].get('appStoreState')})")

        def version_attributes():
            api.patch("appStoreVersions", version["id"], only_set({"copyright": listing.get("copyright")}))

        def version_localization():
            locs = api.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
            loc = next((l for l in locs if l["attributes"]["locale"] == app["locale"]), None)
            attributes = only_set({
                "description": listing.get("description"),
                "keywords": listing.get("keywords"),
                "promotionalText": listing.get("promotional_text"),
                "supportUrl": listing.get("support_url"),
                "marketingUrl": listing.get("marketing_url"),
            })
            if loc:
                api.patch("appStoreVersionLocalizations", loc["id"], attributes)
            else:
                api.post("appStoreVersionLocalizations", {"locale": app["locale"], **attributes},
                         {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}})

        def review_details():
            attributes = {"notes": listing.get("review_notes", ""), "demoAccountRequired": False}
            try:
                detail = api.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")["data"]
            except ApiError:
                detail = None
            if detail:
                current = detail.get("attributes", {})
                if all(current.get(k) == v for k, v in attributes.items()):
                    return
                contact = ("contactFirstName", "contactLastName", "contactEmail", "contactPhone")
                api.patch("appStoreReviewDetails", detail["id"],
                          {**only_set({k: current.get(k) for k in contact}), **attributes})
            else:
                api.post("appStoreReviewDetails", attributes,
                         {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}})

        def screenshots():
            locs = api.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
            loc = next(l for l in locs if l["attributes"]["locale"] == app["locale"])
            for kind, files in screenshot_files(app["locale"]).items():
                print(f"  {kind}: {upload_screenshots(api, loc['id'], kind, files)}")

        step("version copyright", version_attributes)
        step("version localization (description, keywords, promotional text, URLs)", version_localization)
        step("screenshots", screenshots)
        step("review notes", review_details)

    if failures:
        print("\n".join(["", "Not updated:"] + failures))
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--push", action="store_true")
    parser.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID", "HDY587QW5K"))
    parser.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID"))
    parser.add_argument("--key-path", default=os.environ.get("ASC_API_KEY_PATH", str(DEFAULT_KEY)))
    args = parser.parse_args()

    app = json.loads((ROOT / "app.json").read_text())
    listing = load_listing(app["locale"])
    errors = check(listing, app)
    for field in sorted(LIMITS):
        if field in listing:
            print(f"{field}: {len(listing[field])}/{LIMITS[field]}")
    if errors:
        print("\n".join(["", "Listing errors:"] + errors))
        return 1
    print("listing ok")
    if not args.push:
        return 0
    credentials = (args.key_id, args.issuer_id, os.path.expanduser(args.key_path or ""))
    if not all(credentials[:2]) or not os.path.isfile(credentials[2]):
        raise SystemExit("--push needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_API_KEY_PATH (or the flags)")
    return push(listing, app, credentials)


if __name__ == "__main__":
    sys.exit(main())
