"""Reads the manifest of an Android App Bundle without third-party tools.

Usage: python -I tools/aab_manifest.py <bundle.aab>
Prints JSON: {"package", "versionCode", "versionName", "permissions", "meta",
"abis", "is_bundle"}.

In an .aab, base/manifest/AndroidManifest.xml is aapt2's protobuf XML
(frameworks/base/tools/aapt2/Resources.proto), which aapt2 dump cannot read.
Only the few fields needed are decoded:
  XmlNode      { XmlElement element = 1; string text = 2; }
  XmlElement   { string name = 3; repeated XmlAttribute attribute = 4; repeated XmlNode child = 5; }
  XmlAttribute { string name = 2; string value = 3; }
aapt2 keeps every attribute's original text in `value`, so versionCode reads as
the string the build wrote ("38").
"""
import json
import sys
import zipfile

MANIFEST = "base/manifest/AndroidManifest.xml"


def _varint(buf: bytes, i: int) -> tuple[int, int]:
    shift = result = 0
    while True:
        b = buf[i]
        i += 1
        result |= (b & 0x7F) << shift
        if b < 0x80:
            return result, i
        shift += 7


def _fields(buf: bytes):
    """Yields (field_number, wire_type, value) for one protobuf message."""
    i = 0
    while i < len(buf):
        key, i = _varint(buf, i)
        field, wire = key >> 3, key & 7
        if wire == 0:
            value, i = _varint(buf, i)
        elif wire == 2:
            length, i = _varint(buf, i)
            value = buf[i:i + length]
            i += length
        elif wire == 1:
            value, i = buf[i:i + 8], i + 8
        elif wire == 5:
            value, i = buf[i:i + 4], i + 4
        else:
            raise ValueError(f"unsupported wire type {wire}")
        yield field, wire, value


def _element(node: bytes):
    """Returns (name, {attr: value}, [child nodes]) or None for a text node."""
    for field, wire, value in _fields(node):
        if field == 1 and wire == 2:
            name, attrs, children = "", {}, []
            for f, w, v in _fields(value):
                if f == 3 and w == 2:
                    name = v.decode("utf-8")
                elif f == 4 and w == 2:
                    a_name = a_value = ""
                    for af, aw, av in _fields(v):
                        if af == 2 and aw == 2:
                            a_name = av.decode("utf-8")
                        elif af == 3 and aw == 2:
                            a_value = av.decode("utf-8")
                    attrs[a_name] = a_value
                elif f == 5 and w == 2:
                    children.append(v)
            return name, attrs, children
    return None


def read(path: str) -> dict:
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        root = _element(z.read(MANIFEST))
    if root is None or root[0] != "manifest":
        raise ValueError("no <manifest> element")
    _, attrs, children = root
    permissions, meta = [], {}
    stack = list(children)
    while stack:
        el = _element(stack.pop())
        if el is None:
            continue
        name, a, kids = el
        if name == "uses-permission":
            permissions.append(a.get("name", ""))
        elif name == "meta-data":
            meta[a.get("name", "")] = a.get("value", "")
        stack.extend(kids)
    abis = sorted({n.split("/")[2] for n in names if n.startswith("base/lib/") and n.count("/") >= 3})
    return {
        "is_bundle": "BundleConfig.pb" in names and MANIFEST in names,
        "package": attrs.get("package", ""),
        "versionCode": attrs.get("versionCode", ""),
        "versionName": attrs.get("versionName", ""),
        "permissions": sorted(permissions),
        "meta": meta,
        "abis": abis,
    }


if __name__ == "__main__":
    print(json.dumps(read(sys.argv[1]), indent=1))
