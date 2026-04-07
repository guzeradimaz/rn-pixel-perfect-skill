# Pixel Diff — объективное сравнение дизайна и симулятора

Используется в Phase 5 для получения точного % совпадения вместо субъективной ИИ-оценки.

## Скрипт

Сохранён в `references/pixel-diff.py` (создаётся автоматически при первом запуске Phase 5 — скопируй скрипт ниже).

```python
#!/usr/bin/env python3
"""
Pixel diff: сравнивает два изображения и возвращает % совпадения.
Использование: python3 pixel-diff.py <figma.png> <simulator.png> <diff_output.png>
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

    # Привести к одному масштабу (Figma может быть @1x, симулятор — другой)
    if img1.size != img2.size:
        img2 = img2.resize(img1.size, Image.LANCZOS)

    if skip_status_bar:
        img1 = crop_status_bar(img1)
        img2 = crop_status_bar(img2)

    diff = ImageChops.difference(img1, img2)
    arr = np.array(diff, dtype=np.float32)
    match_pct = 100.0 - (arr.mean() / 255.0 * 100.0)

    # Усилить контраст для визуального анализа
    enhanced = ImageEnhance.Contrast(diff).enhance(10)
    enhanced.save(output_path)

    print(f"Match: {match_pct:.1f}%")
    print(f"Diff saved: {output_path}")
    print(f"  White = совпадает, Яркое = расхождение")
    return match_pct


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: python3 pixel-diff.py <figma.png> <sim.png> <diff.png>")
        sys.exit(1)
    result = pixel_diff(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if result >= 95.0 else 1)
```

## Запуск

```bash
# Установить зависимости (один раз)
pip3 install Pillow numpy -q

# Запустить diff
python3 {projectRoot}/.claude/skills/rn-pixel-perfect/references/pixel-diff.py \
  src/assets/figma/HomeScreen_design.png \
  /tmp/HomeScreen_sim_1.png \
  /tmp/HomeScreen_diff_1.png
```

Скрипт вернёт:
- Код выхода `0` — match ≥ 95% (Phase 5 пройдена)
- Код выхода `1` — match < 95% (нужны исправления)

## Интерпретация diff-изображения

| Цвет в diff | Значение |
|-------------|----------|
| Белый / светлый | Совпадает |
| Тёмный | Небольшое расхождение (≤10px разница) |
| Яркий/насыщенный | Значительное расхождение (цвет, размер) |
| Красный блок | Элемент присутствует в одном изображении, отсутствует в другом |

## Типичные паттерны расхождений

```
Горизонтальная полоса по всей ширине → неправильный padding/margin
Смещение всего контента ниже →  неправильный SafeArea / paddingTop
Текст чуть крупнее → неправильный fontSize или lineHeight
Карточки разного размера → vs() вместо scale() на вертикальных отступах
Тени отличаются → нормально (см. допустимые расхождения)
Status bar другой → нормально (исключается crop_status_bar)
```

## Crop для сравнения отдельных секций

Если нужно сравнить только часть экрана (например, только Header):
```python
from PIL import Image

def crop_section(img_path, y_start, y_end):
    img = Image.open(img_path)
    w = img.size[0]
    return img.crop((0, y_start, w, y_end))

header_figma = crop_section('src/assets/figma/Home_design.png', 50, 106)
header_sim   = crop_section('/tmp/Home_sim_1.png', 50, 106)
header_figma.save('/tmp/header_figma.png')
header_sim.save('/tmp/header_sim.png')
# Затем запусти pixel-diff.py на этих файлах
```
