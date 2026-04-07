#!/usr/bin/env python3
"""
Pixel diff: сравнивает два изображения и возвращает % совпадения.
Использование: python3 pixel-diff.py <figma.png> <simulator.png> <diff_output.png>
Коды выхода: 0 = match >= 95%, 1 = match < 95%
"""
from PIL import Image, ImageChops, ImageEnhance
import numpy as np
import sys


def crop_status_bar(img: Image.Image, bar_height_px: int = 50) -> Image.Image:
    """Убирает status bar (верхние N пикселей) — системный UI не считается расхождением."""
    w, h = img.size
    return img.crop((0, bar_height_px, w, h))


def pixel_diff(img1_path: str, img2_path: str, output_path: str, skip_status_bar: bool = True) -> float:
    img1 = Image.open(img1_path).convert('RGB')
    img2 = Image.open(img2_path).convert('RGB')

    # Привести к одному масштабу (Figma @1x vs симулятор logical pixels)
    if img1.size != img2.size:
        img2 = img2.resize(img1.size, Image.LANCZOS)

    if skip_status_bar:
        img1 = crop_status_bar(img1)
        img2 = crop_status_bar(img2)

    diff = ImageChops.difference(img1, img2)
    arr = np.array(diff, dtype=np.float32)
    match_pct = 100.0 - (arr.mean() / 255.0 * 100.0)

    # Усилить контраст для визуального анализа расхождений
    enhanced = ImageEnhance.Contrast(diff).enhance(10)
    enhanced.save(output_path)

    print(f"Match: {match_pct:.1f}%")
    print(f"Diff: {output_path}  (белое=совпадает, яркое=расхождение)")
    return match_pct


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: python3 pixel-diff.py <figma.png> <sim.png> <diff.png>")
        sys.exit(1)
    result = pixel_diff(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if result >= 95.0 else 1)
