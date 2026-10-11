#!/usr/bin/env python3
"""Validate iPhone arm64 Mach-O platform in a compiled IPA, not signing."""
import argparse, hashlib, json, plistlib, struct, sys, zipfile
from pathlib import Path

ARM64 = 0x0100000c
IOS = 2

def validate_macho(data):
    if len(data) < 32:
        raise ValueError("Truncated executable")
    # Fat/universal binaries: validate every slice, not only the first.
    magic = struct.unpack_from(">I", data)[0]
    if magic in (0xcafebabe, 0xcafebabf):
        n = struct.unpack_from(">I", data, 4)[0]
        if not 0 < n < 16:
            raise ValueError("Invalid fat slice count")
        slices = []
        entry = 24 if magic == 0xcafebabf else 20
        for i in range(n):
            pos = 8 + i * entry
            if pos + entry > len(data):
                raise ValueError("Truncated fat header")
            if entry == 24:
                cpu, sub, start, length, align, reserved = struct.unpack_from(">IIQQII", data, pos)
            else:
                cpu, sub, start, length, align = struct.unpack_from(">IIIII", data, pos)
            if start + length > len(data):
                raise ValueError("Invalid fat offset")
            slices.append(data[start:start+length])
    else:
        slices = [data]
    result = []
    for binary in slices:
        if len(binary) < 32 or struct.unpack_from("<I", binary)[0] != 0xfeedfacf:
            raise ValueError("Expected 64-bit little-endian Mach-O")
        cpu, subtype, filetype, count, size, flags, reserved = struct.unpack_from("<IIIIIII", binary, 4)
        if 32 + size > len(binary) or count > 50000:
            raise ValueError("Truncated load commands")
        pos, platform = 32, None
        for _ in range(count):
            if pos + 8 > 32 + size:
                raise ValueError("Invalid load command header")
            cmd, length = struct.unpack_from("<II", binary, pos)
            if length < 8 or pos + length > 32 + size:
                raise ValueError("Invalid load command size")
            if cmd == 0x32:
                if length < 24:
                    raise ValueError("Invalid LC_BUILD_VERSION")
                platform = struct.unpack_from("<I", binary, pos + 8)[0]
            if cmd == 0x25 and platform is None:
                platform = IOS
            pos += length
        result.append({"cpu": cpu, "platform": platform})
    return result

def inspect(ipa, bundle_id):
    problems, binaries = [], []
    h = hashlib.sha256()
    with ipa.open("rb") as file:
        for chunk in iter(lambda: file.read(1048576), b""):
            h.update(chunk)
    with zipfile.ZipFile(ipa) as z:
        names = set(z.namelist())
        apps = [n for n in names if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(apps) != 1:
            raise ValueError("Expected exactly one Payload/*.app/Info.plist")
        root = apps[0][:-len("Info.plist")]
        infos = [apps[0]] + sorted(n for n in names if n.startswith(root+"PlugIns/") and n.endswith(".appex/Info.plist"))
        if len(infos) < 2:
            problems.append("Missing expected app extensions")
        for info_path in infos:
            info = plistlib.loads(z.read(info_path))
            ident, exe = info.get("CFBundleIdentifier"), info.get("CFBundleExecutable")
            if info_path == apps[0] and ident != bundle_id:
                problems.append("App bundle ID mismatch")
            if info_path != apps[0] and not (isinstance(ident,str) and ident.startswith(bundle_id+".")):
                problems.append("Extension bundle ID mismatch")
            if not isinstance(exe,str) or "/" in exe or not exe:
                problems.append(f"Missing executable: {info_path}")
                continue
            member = info_path[:-len("Info.plist")] + exe
            if member not in names:
                problems.append(f"Binary missing: {member}")
                continue
            slices = validate_macho(z.read(member))
            binaries.append({"path": member, "slices": slices})
            if not slices or any(x["cpu"] != ARM64 or x["platform"] != IOS for x in slices):
                problems.append(f"Not iPhone arm64 platform: {member}")
    return {"status": "FAIL" if problems else "PASS", "ipa_sha256": h.hexdigest(), "binaries": binaries, "problems": problems, "warning": "Not a signing, launch, API login or runtime verification."}

if __name__ == "__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("ipa", type=Path)
    ap.add_argument("--bundle-id", required=True)
    ap.add_argument("--report", type=Path)
    a=ap.parse_args()
    try:
        if a.bundle_id.startswith(("org.example.", "org.telegram.", "ph.telegra.")):
            raise ValueError("Expected a distinct Veilgram bundle ID")
        output=inspect(a.ipa,a.bundle_id)
        data=json.dumps(output,indent=2)+"\n"
        print(data)
        if a.report: a.report.write_text(data)
        sys.exit(0 if output["status"]=="PASS" else 1)
    except (ValueError,OSError,KeyError,zipfile.BadZipFile) as error:
        print("FAIL:",error,file=sys.stderr)
        sys.exit(2)
