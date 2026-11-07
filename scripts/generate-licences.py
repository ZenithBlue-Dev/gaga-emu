#!/usr/bin/env python3
"""Writes Sources/App/Licences from the committed list Licences/notices.json.

    scripts/generate-licences.py

Run it after a core, MoltenVK or a crate pin changes, and commit the result. It needs every core's
submodules, build/moltenvk (scripts/build-moltenvk.sh) and the crates Cargo fetched for JGenesis, so it
runs on a full checkout; the app reads only what it writes. Each text is stored once, named by its hash,
and the app shows a component only when one of its cores is linked.
"""
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Sources/App/Licences"
REGISTRY = pathlib.Path.home() / ".cargo/registry/src"

MIT = """Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""
BSD3 = """Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""
ZLIB = """This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.
"""
APACHE = ROOT / "build/moltenvk/licenses/SPIRV-Cross/LICENSES/Apache-2.0.txt"


def fail(message):
    sys.exit(f"generate-licences: {message}")


def comment(path):
    """The first comment block that names a copyright or a licence, without its comment markers."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    blocks, block, in_c = [], [], False
    for line in lines:
        stripped = line.strip()
        if in_c:
            block.append(line)
            if "*/" in stripped:
                in_c = False
            continue
        if stripped.startswith("/*"):
            block.append(line)
            in_c = "*/" not in stripped[2:]
            continue
        if stripped.startswith("//") or (block and not stripped):
            block.append(line)
            continue
        if block:
            blocks.append(block)
            block = []
    if block:
        blocks.append(block)
    for block in blocks:
        text = "\n".join(block)
        if re.search(r"copyright|licen[cs]e|public domain", text, re.I):
            cleaned = []
            for line in block:
                line = re.sub(r"^\s*(/\*+|\*+/|//+|\*+)", "", line.rstrip())
                cleaned.append(re.sub(r"\*+/\s*$", "", line).rstrip())
            return "\n".join(cleaned).strip("\n") + "\n"
    fail(f"no licence comment in {path}")


def crate_dir(spec):
    name, version = spec.split(" ")
    # A version may carry build metadata, as toml's "+spec-1.1.0" does.
    found = sorted(REGISTRY.glob(f"*/{name}-{version}")) or sorted(REGISTRY.glob(f"*/{name}-{version}+*"))
    if not found:
        fail(f"crate {spec} is not in {REGISTRY}. Build JGenesis first: scripts/build-core.sh jgenesis")
    return found[0]


def crate_text(spec):
    """The crate's MIT text where it offers MIT, else its own licence file, else the standard text
    for its Cargo.toml licence with its authors as the copyright holders."""
    folder = crate_dir(spec)
    # The normalized Cargo.toml crates.io ships; macOS's Python 3.9 has no tomllib.
    toml = (folder / "Cargo.toml").read_text()
    found = re.search(r'^license\s*=\s*"([^"]*)"', toml, re.M)
    licence = found.group(1) if found else ""
    authors = re.search(r"^authors\s*=\s*\[(.*?)\]", toml, re.M | re.S)
    manifest = {"authors": re.findall(r'"([^"]*)"', authors.group(1)) if authors else []}
    names = ["LICENSE-MIT", "LICENSE-MIT.md", "LICENSE-MIT.txt", "LICENSE.Mit"] if "MIT" in licence else []
    names += ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENSE-ZLIB", "LICENSE-ZLIB.md", "COPYING"]
    for name in names:
        if (folder / name).is_file():
            return licence, (folder / name).read_text(encoding="utf-8", errors="replace")
    holders = ", ".join(manifest.get("authors", [])) or f"the {spec.split()[0]} authors"
    if "MIT" in licence:
        body = MIT
    elif "BSD-3-Clause" in licence:
        body = BSD3
    elif "Zlib" in licence:
        body = ZLIB
    elif "Apache-2.0" in licence:
        return licence, APACHE.read_text()
    else:
        fail(f"crate {spec} has licence {licence!r} and no licence file")
    return licence, f"Copyright (c) {holders}\n\n{body}"


def text_of(item):
    if "text" in item:
        return item["text"]
    if "crate" in item:
        return (crate_dir(item["crate"]) / item["file"]).read_text(encoding="utf-8", errors="replace")
    path = ROOT / item["from"]
    if not path.is_file():
        fail(f"{item['from']} is missing. Check out every submodule and run scripts/build-moltenvk.sh.")
    if item.get("comment"):
        return comment(path)
    content = path.read_text(encoding="utf-8", errors="replace")
    if "lines" in item:
        first, last = item["lines"]
        content = "\n".join(content.splitlines()[first - 1:last]) + "\n"
    return content


def store(content, written):
    name = "licence-" + hashlib.sha256(content.encode()).hexdigest()[:12] + ".txt"
    written[name] = content
    return name


def main():
    source = json.loads((ROOT / "Licences/notices.json").read_text())
    written, components = {}, []
    for component in source["components"]:
        texts = []
        for spec in component.get("crates", []):
            licence, content = crate_text(spec)
            texts.append({"title": f"{spec} ({licence})", "file": store(content, written)})
        for item in component["texts"]:
            texts.append({"title": item["title"], "file": store(text_of(item), written)})
        entry = {key: component[key] for key in ("id", "title", "licence", "source") }
        entry["cores"] = component.get("cores", [])
        if "framework" in component:
            entry["framework"] = component["framework"]
        entry["texts"] = texts
        components.append(entry)

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("licence-*.txt"):
        if old.name not in written:
            old.unlink()
    for name, content in written.items():
        (OUT / name).write_text(content)
    (OUT / "licences.json").write_text(json.dumps({"components": components}, indent=1) + "\n")
    print(f"{len(components)} components, {len(written)} texts in {OUT.relative_to(ROOT)}")


main()
