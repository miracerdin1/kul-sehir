"""Retarget Mixamo locomotion onto the SWAT rig and preserve embedded textures."""

from hashlib import sha256
import json
import math
from pathlib import Path
import struct
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache"
IDENTITY = (0.0, 0.0, 0.0, 1.0)
SWAT_URL = "https://pub-2534e921bf9c4314addcd4d8a6e98b7b.r2.dev/avatars/mixamo/glb/swat.glb"
ANIMATION_ROOT = "https://raw.githubusercontent.com/MisterYI/deevid-mixamo-assets/main/anim/"


def fetch(url, path):
    if not path.exists():
        with urllib.request.urlopen(url, timeout=90) as response:
            path.write_bytes(response.read())
    return path


def read_glb(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    binary_start = 20 + length
    size = struct.unpack_from("<I", data, binary_start)[0]
    return document, bytearray(data[binary_start + 8:binary_start + 8 + size])


def multiply(a, b):
    x, y, z, w = a
    u, v, s, t = b
    return (w*u+x*t+y*s-z*v, w*v-x*s+y*t+z*u, w*s+x*v-y*u+z*t, w*t-x*u-y*v-z*s)


def inverse(q):
    norm = sum(value * value for value in q)
    return (-q[0]/norm, -q[1]/norm, -q[2]/norm, q[3]/norm)


def normalize(q):
    norm = math.sqrt(sum(value * value for value in q))
    return tuple(value / norm for value in q)


def rotation_globals(document):
    nodes = document["nodes"]
    parents = {child: parent for parent, node in enumerate(nodes) for child in node.get("children", [])}
    rotations = {}

    def world(index):
        if index not in rotations:
            parent = world(parents[index]) if index in parents else IDENTITY
            rotations[index] = normalize(multiply(parent, nodes[index].get("rotation", IDENTITY)))
        return rotations[index]

    for index in range(len(nodes)):
        world(index)
    return parents, rotations


def samples(document, binary, index):
    accessor = document["accessors"][index]
    if accessor["componentType"] != 5126 or "sparse" in accessor:
        raise ValueError("Only dense float animation accessors are supported")
    width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    view = document["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", width * 4)
    return [struct.unpack_from("<" + "f" * width, binary, offset + row * stride)
            for row in range(accessor["count"])]


def append_accessor(document, binary, values, kind):
    binary.extend(b"\x00" * (-len(binary) % 4))
    offset = len(binary)
    for row in values:
        binary.extend(struct.pack("<" + "f" * len(row), *row))
    view = len(document["bufferViews"])
    document["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset})
    accessor = {"bufferView": view, "componentType": 5126, "count": len(values), "type": kind}
    if kind == "SCALAR":
        accessor.update(min=[values[0][0]], max=[values[-1][0]])
    index = len(document["accessors"])
    document["accessors"].append(accessor)
    return index


def retarget(target, binary, source, source_binary, name):
    target_parents, target_world = rotation_globals(target)
    source_parents, source_world = rotation_globals(source)
    targets = {node.get("name"): index for index, node in enumerate(target["nodes"])}
    animation = {"name": name, "channels": [], "samplers": []}
    for channel in source["animations"][0]["channels"]:
        source_index = channel["target"]["node"]
        bone_name = source["nodes"][source_index].get("name")
        target_index = targets.get(bone_name)
        kind = channel["target"]["path"]
        if target_index is None or kind not in ("rotation", "translation"):
            continue
        if kind == "translation" and bone_name != "mixamorig:Hips":
            continue
        sampler = source["animations"][0]["samplers"][channel["sampler"]]
        if sampler.get("interpolation", "LINEAR") != "LINEAR":
            raise ValueError("Expected linear animation samples")
        values = samples(source, source_binary, sampler["output"])
        if kind == "rotation":
            source_parent = source_world.get(source_parents.get(source_index), IDENTITY)
            target_parent = target_world.get(target_parents.get(target_index), IDENTITY)
            left = multiply(inverse(target_parent), source_parent)
            right = multiply(inverse(source_world[source_index]), target_world[target_index])
            values = [normalize(multiply(multiply(left, value), right)) for value in values]
        else:
            rest = target["nodes"][target_index]["translation"]
            source_rest = source["nodes"][source_index]["translation"]
            scale = rest[1] / source_rest[1]
            values = [(rest[0], rest[1] + (value[1] - source_rest[1]) * scale, rest[2]) for value in values]
        times = samples(source, source_binary, sampler["input"])
        animation["channels"].append({"sampler": len(animation["samplers"]), "target": {"node": target_index, "path": kind}})
        animation["samplers"].append({
            "input": append_accessor(target, binary, times, "SCALAR"),
            "output": append_accessor(target, binary, values, "VEC4" if kind == "rotation" else "VEC3"),
            "interpolation": "LINEAR",
        })
    return animation


def write_glb(document, binary, path):
    document["buffers"] = [{"byteLength": len(binary)}]
    binary.extend(b"\x00" * (-len(binary) % 4))
    header = json.dumps(document, separators=(",", ":")).encode()
    header += b" " * (-len(header) % 4)
    size = 12 + 8 + len(header) + 8 + len(binary)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, size)
                     + struct.pack("<II", len(header), 0x4E4F534A) + header
                     + struct.pack("<II", len(binary), 0x004E4942) + binary)


def main():
    CACHE.mkdir(exist_ok=True)
    swat = fetch(SWAT_URL, CACHE / "swat.glb")
    target, binary = read_glb(swat)
    target["animations"] = []
    sources = [{"url": SWAT_URL, "sha256": sha256(swat.read_bytes()).hexdigest()}]
    for source_name, name in (("Idle", "Idle"), ("Walking", "Walk"), ("Running", "Run")):
        url = ANIMATION_ROOT + source_name + ".glb"
        path = fetch(url, CACHE / (source_name.lower() + ".glb"))
        source, source_binary = read_glb(path)
        target["animations"].append(retarget(target, binary, source, source_binary, name))
        sources.append({"url": url, "sha256": sha256(path.read_bytes()).hexdigest()})
    output = ROOT / "godot" / "assets" / "characters" / "survivor.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    write_glb(target, binary, output)
    credits = {"character": "SWAT by Adobe Mixamo", "animations": "Idle / Walking / Running by Adobe Mixamo",
               "sources": sources, "license": "Mixamo embedded project use; not CC0; no standalone redistribution",
               "terms": "https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html",
               "modifications": "Locomotion retargeted to SWAT rest skeleton, horizontal root motion removed.",
               "output_sha256": sha256(output.read_bytes()).hexdigest()}
    output.with_suffix(".credits.json").write_text(json.dumps(credits, indent=2), encoding="utf-8")
    print("SWAT survivor ready, with Idle / Walk / Run.")


if __name__ == "__main__":
    main()
