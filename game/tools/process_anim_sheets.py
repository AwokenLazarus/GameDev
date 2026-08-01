#!/usr/bin/env python3
"""Slice Bloodlust animation sheets into per-state frame PNGs."""
from __future__ import annotations

import re
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path("/opt/cursor/artifacts/assets")
ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"
SHOW = ROOT / "assets" / "art_showcase" / "anims"

# actor_id -> (folder, expected sheet stems without anim_ prefix)
ACTORS: dict[str, str] = {
    # heroes
    "severin": "characters",
    "mira": "characters",
    "cassian": "characters",
    "odette": "characters",
    "vesper": "characters",
    # enemies
    "human_enforcer": "enemies",
    "church_zealot": "enemies",
    "dominion_grub": "enemies",
    "dominion_elite": "enemies",
    "beast_hound": "enemies",
    "void_wretch": "enemies",
    # generals
    "marshal_hale": "generals",
    "lady_sable": "generals",
    "marrowfang": "generals",
    "cantor_belis": "generals",
    "provost_rhea": "generals",
    "duke_orlokis": "generals",
    "admiral_drus": "generals",
    "aurelian": "generals",
    # hub npcs
    "npc_mayor": "npcs",
    "npc_kin": "npcs",
    "npc_dust_vendor": "npcs",
    "npc_church": "npcs",
    "npc_petition": "npcs",
    "npc_veyra": "npcs",
}

FRAME_COUNTS = {
    "idle": 2,
    "walk": 4,
    "run": 4,
    "attack": 4,
    "dodge": 3,
}

# NPC idle sheets are 2 idle + 2 talk
NPC_IDLE_AS_TALK = True

HEIGHTS = {
    "characters": 256,
    "enemies": 192,
    "generals": 288,
    "npcs": 224,
}


def key_green(img: Image.Image) -> Image.Image:
    arr = np.array(img.convert("RGBA"), dtype=np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    greenness = g - np.maximum(r, b)
    hard = (g > 90) & (greenness > 35)
    soft = np.clip((greenness - 10.0) / 28.0, 0.0, 1.0)
    alpha = a.copy()
    alpha[hard] = 0.0
    edge = (~hard) & (soft > 0.15) & (g > 70)
    alpha[edge] *= 1.0 - soft[edge]
    arr[:, :, 3] = alpha
    spill = (arr[:, :, 3] > 8) & (g > r + 8) & (g > b + 8)
    arr[spill, 1] = np.minimum(arr[spill, 1], (arr[spill, 0] + arr[spill, 2]) * 0.55)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def content_columns(alpha: np.ndarray, thresh: int = 12) -> np.ndarray:
    return (alpha > thresh).any(axis=0)


def split_frames(img: Image.Image, expected: int) -> list[Image.Image]:
    """Split a keyed sheet into expected frames via column occupancy gaps."""
    arr = np.array(img)
    alpha = arr[:, :, 3]
    cols = content_columns(alpha)
    if not cols.any():
        return []

    # Find runs of content
    padded = np.concatenate([[False], cols, [False]])
    diff = np.diff(padded.astype(np.int8))
    starts = np.where(diff == 1)[0]
    ends = np.where(diff == -1)[0]
    runs = list(zip(starts.tolist(), ends.tolist()))
    if not runs:
        return []

    # Merge tiny noise runs; then if too many runs, keep largest N
    min_w = max(8, img.width // (expected * 8))
    runs = [(s, e) for s, e in runs if (e - s) >= min_w]
    if not runs:
        # fallback equal split of bbox
        ys = np.where(alpha.max(axis=1) > 12)[0]
        xs = np.where(cols)[0]
        if len(xs) == 0 or len(ys) == 0:
            return []
        x0, x1 = int(xs[0]), int(xs[-1]) + 1
        y0, y1 = int(ys[0]), int(ys[-1]) + 1
        band = img.crop((x0, y0, x1, y1))
        w = band.width // expected
        return [band.crop((i * w, 0, (i + 1) * w if i < expected - 1 else band.width, band.height)) for i in range(expected)]

    if len(runs) > expected:
        # merge closest neighbors until expected
        while len(runs) > expected:
            gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
            i = int(np.argmin(gaps))
            runs[i] = (runs[i][0], runs[i + 1][1])
            del runs[i + 1]
    elif len(runs) < expected:
        # equal-split the full content span
        x0, x1 = runs[0][0], runs[-1][1]
        ys = np.where(alpha.max(axis=1) > 12)[0]
        y0, y1 = int(ys[0]), int(ys[-1]) + 1
        span = x1 - x0
        w = span / expected
        frames = []
        for i in range(expected):
            a = int(x0 + i * w)
            b = int(x0 + (i + 1) * w) if i < expected - 1 else x1
            frames.append(img.crop((a, y0, b, y1)))
        return [trim(f) for f in frames if f.getbbox()]

    ys = np.where(alpha.max(axis=1) > 12)[0]
    y0, y1 = int(ys[0]), int(ys[-1]) + 1
    frames = []
    for s, e in runs[:expected]:
        # pad a bit into gaps
        pad = 4
        a = max(0, s - pad)
        b = min(img.width, e + pad)
        frames.append(trim(img.crop((a, y0, b, y1))))
    # if still short, pad by duplicating last
    while len(frames) < expected and frames:
        frames.append(frames[-1].copy())
    return frames[:expected]


def trim(img: Image.Image, pad: int = 6) -> Image.Image:
    bbox = img.split()[-1].getbbox()
    if not bbox:
        return img
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(img.width, r + pad)
    b = min(img.height, b + pad)
    return img.crop((l, t, r, b))


def fit_height(img: Image.Image, h: int) -> Image.Image:
    if img.height <= 0:
        return img
    scale = h / float(img.height)
    w = max(1, int(round(img.width * scale)))
    return img.resize((w, h), Image.Resampling.LANCZOS)


def save_frames(frames: list[Image.Image], folder: str, name: str, anim: str, height: int) -> None:
    out = TEX / folder
    out.mkdir(parents=True, exist_ok=True)
    for i, fr in enumerate(frames):
        fit_height(fr, height).save(out / f"{name}_{anim}_f{i}.png")
    # legacy walk alias for old ActorVisual
    if anim == "walk":
        for i, fr in enumerate(frames):
            fit_height(fr, height).save(out / f"{name}_f{i}.png")
        if frames:
            fit_height(frames[0], height).save(out / f"{name}.png")
    print(f"  {folder}/{name}_{anim} x{len(frames)}")


def parse_sheet_name(path: Path) -> tuple[str, str] | None:
    # anim_{actor}_{anim}.png  where actor may contain underscores
    m = re.match(r"anim_(.+)_(idle|walk|run|attack|dodge)\.png$", path.name)
    if not m:
        return None
    return m.group(1), m.group(2)


def main() -> None:
    SHOW.mkdir(parents=True, exist_ok=True)
    sheets = sorted(SRC.glob("anim_*.png"))
    print(f"Found {len(sheets)} anim sheets")
    for path in sheets:
        parsed = parse_sheet_name(path)
        if not parsed:
            print("  skip", path.name)
            continue
        actor, anim = parsed
        folder = ACTORS.get(actor)
        if folder is None:
            print("  unknown actor", actor)
            continue
        shutil.copy2(path, SHOW / path.name)
        keyed = key_green(Image.open(path))
        expected = FRAME_COUNTS.get(anim, 4)
        # NPC idle sheets encoded as 4 frames (2 idle + 2 talk)
        if actor.startswith("npc_") and anim == "idle":
            expected = 4
        frames = split_frames(keyed, expected)
        if not frames:
            print("  FAILED slice", path.name)
            continue
        h = HEIGHTS[folder]
        if actor.startswith("npc_") and anim == "idle" and NPC_IDLE_AS_TALK and len(frames) >= 4:
            save_frames(frames[:2], folder, actor, "idle", h)
            save_frames(frames[2:4], folder, actor, "talk", h)
        else:
            save_frames(frames, folder, actor, anim, h)
            # enemies/generals/npcs without run: copy walk→run for API completeness
            if anim == "walk" and folder != "characters":
                save_frames(frames, folder, actor, "run", h)

    # Heroes missing run fallback already generated; ensure enemies have dodge=idle flash-ready copy of walk[0]
    for actor, folder in ACTORS.items():
        idle0 = TEX / folder / f"{actor}_idle_f0.png"
        dodge0 = TEX / folder / f"{actor}_dodge_f0.png"
        if idle0.exists() and not dodge0.exists():
            img = Image.open(idle0)
            for i in range(2):
                img.save(TEX / folder / f"{actor}_dodge_f{i}.png")
            print(f"  dodge fallback {actor}")

    print("Done.")


if __name__ == "__main__":
    main()
