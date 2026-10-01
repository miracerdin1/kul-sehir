"""Fetch pinned runtime and attributed prototype assets. No build or export."""

from concurrent.futures import ThreadPoolExecutor
from hashlib import md5, sha256
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
HEADERS = {"User-Agent": "KulSehirPrototype/0.1 (local game prototype)"}
VERSION = "4.7.2-stable"
MODELS = (
    "covered_car", "barrel_stove", "concrete_road_barrier",
    "metal_jerrycan", "long_life_food", "can_rusted", "rock_04",
)
TEXTURES = ("aerial_asphalt_01", "brick_wall_001", "blue_plaster_weathered", "rubble")


def request(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=120)


def read_json(url):
    with request(url) as response:
        return json.load(response)


def download(url, path, checksum=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and (not checksum or md5(path.read_bytes()).hexdigest() == checksum):
        return
    with request(url) as response:
        data = response.read()
    if checksum and md5(data).hexdigest() != checksum:
        raise ValueError(f"Checksum mismatch: {path.name}")
    temporary = path.with_suffix(path.suffix + ".part")
    temporary.write_bytes(data)
    temporary.replace(path)


def fetch_model(asset_id):
    files = read_json(f"https://api.polyhaven.com/files/{asset_id}")
    entry = files["gltf"]["1k"]["gltf"]
    folder = PROJECT / "assets" / "models" / asset_id
    download(entry["url"], folder / f"{asset_id}.gltf", entry["md5"])
    for name, item in entry["include"].items():
        target = (folder / name).resolve()
        if not target.is_relative_to(folder.resolve()):
            raise ValueError("Unexpected asset path")
        download(item["url"], target, item["md5"])
    info = read_json(f"https://api.polyhaven.com/info/{asset_id}")
    print(f"Model ready: {asset_id}", flush=True)
    return {"id": asset_id, "source": f"https://polyhaven.com/a/{asset_id}",
            "license": "CC0-1.0", "authors": info.get("authors", {}), "files": entry}


def fetch_texture(asset_id):
    files = read_json(f"https://api.polyhaven.com/files/{asset_id}")
    folder = PROJECT / "assets" / "textures" / asset_id
    selected = {}
    for channel, remote in (("diff", "Diffuse"), ("nor_gl", "nor_gl"), ("rough", "Rough")):
        item = files[remote]["1k"]["jpg"]
        download(item["url"], folder / f"{channel}.jpg", item["md5"])
        selected[channel] = item
    info = read_json(f"https://api.polyhaven.com/info/{asset_id}")
    print(f"Texture ready: {asset_id}", flush=True)
    return {"id": asset_id, "source": f"https://polyhaven.com/a/{asset_id}",
            "license": "CC0-1.0", "authors": info.get("authors", {}), "files": selected}


def fetch_runtime():
    name = f"Godot_v{VERSION}_win64.exe.zip"
    release = read_json(f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}")
    entry = next(item for item in release["assets"] if item["name"] == name)
    archive = ROOT / ".cache" / name
    download(entry["browser_download_url"], archive)
    digest = entry.get("digest")
    if not digest or digest != "sha256:" + sha256(archive.read_bytes()).hexdigest():
        raise ValueError("Godot release SHA256 validation failed")
    target = ROOT / ".tools" / "godot"
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            if not (target / entry.filename).resolve().is_relative_to(target.resolve()):
                raise ValueError("Unexpected archive path")
        package.extractall(target)
    print(f"Godot verified and ready: {VERSION}", flush=True)


def main():
    with ThreadPoolExecutor(max_workers=4) as pool:
        runtime = pool.submit(fetch_runtime)
        futures = [pool.submit(fetch_model, asset_id) for asset_id in MODELS]
        futures += [pool.submit(fetch_texture, asset_id) for asset_id in TEXTURES]
        manifest = [future.result() for future in futures]
        runtime.result()
    (PROJECT / "assets" / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print("All assets ready; manifest saved.", flush=True)


if __name__ == "__main__":
    main()
