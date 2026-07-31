#!/usr/bin/env python3
"""Chroma-key Bloodlust art into Godot textures + idle walk frames."""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = Path("/opt/cursor/artifacts/assets")
SHOW = ROOT / "assets" / "art_showcase"
TEX = ROOT / "assets" / "textures"


def key_green(img: Image.Image, soft: float = 28.0) -> Image.Image:
    arr = np.array(img.convert("RGBA"), dtype=np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    greenness = g - np.maximum(r, b)
    # Strong green screen
    hard = (g > 90) & (greenness > 35)
    soft_mask = np.clip((greenness - 10.0) / soft, 0.0, 1.0)
    alpha = a.copy()
    alpha[hard] = 0.0
    edge = (~hard) & (soft_mask > 0.15) & (g > 70)
    alpha[edge] = alpha[edge] * (1.0 - soft_mask[edge])
    arr[:, :, 3] = alpha
    # Despill remaining green fringe
    spill = (arr[:, :, 3] > 8) & (g > r + 8) & (g > b + 8)
    arr[spill, 1] = np.minimum(arr[spill, 1], (arr[spill, 0] + arr[spill, 2]) * 0.55)
    out = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return trim(out)


def key_black(img: Image.Image, thresh: float = 28.0) -> Image.Image:
    arr = np.array(img.convert("RGBA"), dtype=np.float32)
    lum = 0.2126 * arr[:, :, 0] + 0.7152 * arr[:, :, 1] + 0.0722 * arr[:, :, 2]
    alpha = np.clip((lum - thresh) / 40.0, 0.0, 1.0) * arr[:, :, 3]
    arr[:, :, 3] = alpha
    out = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return trim(out)


def trim(img: Image.Image, pad: int = 8) -> Image.Image:
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


def walk_frames(img: Image.Image) -> list[Image.Image]:
    frames = []
    for i, (dx, dy, rot, sc) in enumerate(
        [
            (0, 0, 0.0, 1.00),
            (2, -3, -1.5, 1.01),
            (0, 1, 0.5, 0.99),
            (-2, -2, 1.2, 1.015),
        ]
    ):
        f = img.copy()
        if abs(rot) > 0.01:
            f = f.rotate(rot, resample=Image.Resampling.BICUBIC, expand=True)
        if abs(sc - 1.0) > 0.001:
            nw = max(1, int(f.width * sc))
            nh = max(1, int(f.height * sc))
            f = f.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (img.width + 16, img.height + 16), (0, 0, 0, 0))
        x = (canvas.width - f.width) // 2 + dx
        y = (canvas.height - f.height) // 2 + dy
        canvas.paste(f, (x, y), f)
        # subtle brightness pulse
        enh = ImageEnhance.Brightness(canvas)
        canvas = enh.enhance(1.0 + (0.04 if i % 2 else 0.0))
        frames.append(trim(canvas, pad=4))
    return frames


def save_actor(img: Image.Image, folder: str, name: str, height: int) -> None:
    out_dir = TEX / folder
    out_dir.mkdir(parents=True, exist_ok=True)
    base = fit_height(img, height)
    base.save(out_dir / f"{name}.png")
    for i, fr in enumerate(walk_frames(base)):
        fit_height(fr, height).save(out_dir / f"{name}_f{i}.png")
    print(f"  actor {folder}/{name}")


def copy_show(src_name: str, dest_name: str | None = None) -> Path:
    SHOW.mkdir(parents=True, exist_ok=True)
    dest = SHOW / (dest_name or src_name)
    shutil.copy2(SRC / src_name, dest)
    return dest


def main() -> None:
    print("Processing Bloodlust art pass…")

    # --- Heroes ---
    heroes = {
        "severin": "hero_severin.png",
        "mira": "hero_mira.png",
        "cassian": "hero_cassian.png",
        "odette": "hero_odette.png",
        "vesper": "hero_vesper.png",
    }
    for name, src in heroes.items():
        copy_show(src, f"{name}_hero.png")
        save_actor(key_green(Image.open(SRC / src)), "characters", name, 256)

    # --- Generals ---
    generals = {
        "aurelian": "boss_aurelian.png",
        "lady_sable": "boss_lady_sable.png",
        "marshal_hale": "boss_marshal_hale.png",
        "admiral_drus": "boss_admiral_drus.png",
        "cantor_belis": "boss_cantor_belis.png",
        "duke_orlokis": "boss_duke_orlokis.png",
        "marrowfang": "boss_marrowfang.png",
        "provost_rhea": "boss_provost_rhea.png",
    }
    for name, src in generals.items():
        copy_show(src, f"{name}_boss.png")
        save_actor(key_green(Image.open(SRC / src)), "generals", name, 320)

    # --- Enemies ---
    enemies = {
        "human_enforcer": "enemy_human.png",
        "church_zealot": "enemy_zealot.png",
        "dominion_grub": "enemy_grub.png",
        "dominion_elite": "enemy_elite.png",
        "beast_hound": "enemy_beast.png",
        "void_wretch": "enemy_void.png",
    }
    for name, src in enemies.items():
        copy_show(src)
        save_actor(key_green(Image.open(SRC / src)), "enemies", name, 192)

    # --- Props ---
    props = {
        "chapel": "prop_chapel.png",
        "crate": "prop_crate.png",
        "rail": "prop_rail.png",
        "ruin": "prop_ruin.png",
    }
    prop_dir = TEX / "props"
    prop_dir.mkdir(parents=True, exist_ok=True)
    for name, src in props.items():
        copy_show(src)
        img = key_green(Image.open(SRC / src))
        # props keep larger detail
        h = 220 if name != "rail" else 140
        fit_height(img, h).save(prop_dir / f"{name}.png")
        print(f"  prop {name}")

    # --- VFX (black key) ---
    vfx = {
        "slash": "vfx_slash.png",
        "blood": "vfx_blood.png",
        "bolt": "vfx_bolt.png",
        "crescent": "vfx_crescent.png",
        "dust": "vfx_dust.png",
        "gear": "vfx_gear.png",
        "moon": "vfx_moon.png",
        "shadow_birth": "vfx_shadow_birth.png",
        "telegraph": "vfx_telegraph.png",
    }
    vfx_dir = TEX / "vfx"
    vfx_dir.mkdir(parents=True, exist_ok=True)
    for name, src in vfx.items():
        copy_show(src)
        img = key_black(Image.open(SRC / src), thresh=22.0 if name != "shadow_birth" else 12.0)
        # soften edges slightly
        img = img.filter(ImageFilter.SMOOTH)
        target = 160 if name in {"moon", "shadow_birth", "telegraph"} else 128
        fit_height(img, target).save(vfx_dir / f"{name}.png")
        print(f"  vfx {name}")

    # --- UI ---
    ui_dir = TEX / "ui"
    ui_dir.mkdir(parents=True, exist_ok=True)
    copy_show("ui_button.png")
    btn = Image.open(SRC / "ui_button.png").convert("RGBA")
    btn.resize((512, 128), Image.Resampling.LANCZOS).save(ui_dir / "button.png")
    print("  ui button")

    # Keep existing painterly vistas in showcase if present in SRC
    for biome in [
        "ashwick",
        "dust_meridian",
        "gloampine",
        "cinder_barrens",
        "iron_orchard",
        "noir_cathedral",
        "salt_choir",
        "umbral_marches",
        "pale_spire",
    ]:
        src = SRC / f"biome_{biome}.png"
        if src.exists():
            copy_show(src.name)

    print("Done.")


if __name__ == "__main__":
    main()
