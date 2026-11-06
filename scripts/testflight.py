#!/usr/bin/env python3
"""Put an uploaded build on TestFlight internal testing.

Waits until build BUILD_NUMBER finishes processing, sets export compliance if still unset,
adds the build to the internal beta group "Internal" (created if missing), and adds the
tester TESTER_EMAIL (an App Store Connect user) to that group.

Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_API_KEY_PATH from the environment, like
appstore_metadata.py. The app is looked up by bundle id (no hardcoded App Store Connect id).

    scripts/testflight.py BUILD_NUMBER TESTER_EMAIL
"""

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from appstore_metadata import Api, ApiError, DEFAULT_KEY  # noqa: E402

BUNDLE_ID = "com.zenithblue.gagaemu"
GROUP = "Internal"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: testflight.py BUILD_NUMBER TESTER_EMAIL")
    build_number, email = sys.argv[1], sys.argv[2]
    credentials = (os.environ.get("ASC_KEY_ID", "HDY587QW5K"),
                   os.environ["ASC_ISSUER_ID"],
                   os.path.expanduser(os.environ.get("ASC_API_KEY_PATH", str(DEFAULT_KEY))))
    api = Api(*credentials)

    apps = api.get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit(f"no App Store Connect app for {BUNDLE_ID}")
    app_id = apps[0]["id"]

    build, started = None, time.time()
    while True:
        if time.time() - started > 10 * 60:
            api = Api(*credentials)  # the token lives 15 minutes
            started = time.time()
        found = api.get("/v1/builds", **{"filter[app]": app_id, "filter[version]": build_number,
                                         "sort": "-uploadedDate", "limit": "1"})["data"]
        state = found[0]["attributes"]["processingState"] if found else "NOT_FOUND"
        print("processingState:", state, flush=True)
        if state == "VALID":
            build = found[0]
            break
        if state in ("INVALID", "FAILED"):
            raise SystemExit(f"build {build_number} is {state}")
        time.sleep(60)

    if build["attributes"].get("usesNonExemptEncryption") is None:
        api.patch("builds", build["id"], {"usesNonExemptEncryption": False})

    groups = api.get(f"/v1/apps/{app_id}/betaGroups", limit="200")["data"]
    group = next((g for g in groups if g["attributes"]["name"] == GROUP
                  and g["attributes"]["isInternalGroup"]), None)
    if group is None:
        group = api.post("betaGroups", {"name": GROUP, "isInternalGroup": True,
                                        "hasAccessToAllBuilds": True},
                         {"app": {"data": {"type": "apps", "id": app_id}}})["data"]
    gid = group["id"]
    try:
        api.call("POST", f"/v1/betaGroups/{gid}/relationships/builds",
                 {"data": [{"type": "builds", "id": build["id"]}]})
    except ApiError as error:  # groups with access to all builds already have it
        print("add build:", error)

    testers = api.get("/v1/betaTesters", **{"filter[email]": email, "filter[apps]": app_id})["data"]
    if testers:
        api.call("POST", f"/v1/betaGroups/{gid}/relationships/betaTesters",
                 {"data": [{"type": "betaTesters", "id": testers[0]["id"]}]})
    else:
        api.post("betaTesters", {"email": email},
                 {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}})

    builds = [b["id"] for b in api.get(f"/v1/betaGroups/{gid}/builds", limit="200")["data"]]
    members = [t["attributes"]["email"] for t in
               api.get(f"/v1/betaGroups/{gid}/betaTesters", limit="200")["data"]]
    detail = api.get(f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]
    icon = api.get(f"/v1/builds/{build['id']}", **{"fields[builds]": "iconAssetToken"})
    print("build id:", build["id"], "in group:", build["id"] in builds)
    print("group:", GROUP, gid, "testers:", members)
    print("internalBuildState:", detail.get("internalBuildState"))
    print("icon present:", bool(icon["data"]["attributes"].get("iconAssetToken")))


if __name__ == "__main__":
    main()
