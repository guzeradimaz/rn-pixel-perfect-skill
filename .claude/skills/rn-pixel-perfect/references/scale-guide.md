# Scale Calculation Reference

## Когда что применять

```
scale(n)   — всё что горизонтальное
vs(n)      — всё что вертикальное
ms(n)      — шрифты, иконки, смешанные квадратные размеры
напрямую   — letterSpacing, opacity, zIndex, borderWidth (1–2px), flex values
```

## Частые ошибки

### ❌ Перепутать scale и vs
```typescript
// Неправильно: высота через scale, ширина через vs
height: scale(52),          // scale — горизонталь!
width: vs(200),             // vs — вертикаль!

// Правильно:
height: vs(52),
width: scale(200),
```

### ❌ Масштабировать letterSpacing
```typescript
// Неправильно:
letterSpacing: scale(-0.3),  // искажает трекинг

// Правильно:
letterSpacing: -0.3,         // берётся из Figma напрямую
```

### ❌ Масштабировать borderWidth
```typescript
// Неправильно:
borderWidth: scale(1),       // даст дробные значения

// Правильно:
borderWidth: 1,              // пиксели границ не масштабируются
```

### ❌ Использовать ms() для отступов
```typescript
// Неправильно:
paddingHorizontal: ms(16),   // ms — для шрифтов

// Правильно:
paddingHorizontal: scale(16),
```

## Расчёт BASE_WIDTH

Если Figma-фрейм НЕ 390pt:

```typescript
// Если дизайн под 393pt (iPhone 14 Pro / 15 Pro / 16):
const BASE_WIDTH = 393;
// ⚠️ Часто путают с 390! Разница всего 3px, но даёт ~0.8% ошибку по всему экрану.

// Если дизайн под 375pt (iPhone SE, старый стандарт):
const BASE_WIDTH = 375;

// Если дизайн под 430pt (iPhone 14 Pro Max):
const BASE_WIDTH = 430;

// Если дизайн под 360pt (Android стандарт):
const BASE_WIDTH = 360;
```

Проверяй в get_design_context — там будет ширина фрейма. Обрати особое внимание на 390 vs 393.

## Типичные размеры из Figma → RN

### Кнопки
```typescript
// Full-width primary button (стандарт)
height: vs(52),
borderRadius: scale(12),
paddingHorizontal: scale(24),

// Small button / chip
height: vs(36),
borderRadius: scale(8),
paddingHorizontal: scale(16),

// Icon button
width: scale(44),
height: scale(44),   // квадрат — можно scale или vs, но единообразно
borderRadius: scale(22),  // круглая
```

### Инпуты
```typescript
height: vs(52),           // стандартный инпут
borderRadius: scale(10),
paddingHorizontal: scale(16),
fontSize: ms(16),
```

### Карточки
```typescript
borderRadius: scale(16),
padding: scale(16),      // или paddingH + paddingV отдельно
...getShadow('md'),
```

### Аватары
```typescript
// Avatars — квадратные, используй scale для обоих измерений
width: scale(40),
height: scale(40),
borderRadius: scale(20),  // половина = круг
```

### Иконки
```typescript
// Иконки — ms(), потому что они масштабируются как шрифт
width: ms(24),
height: ms(24),
```

### Навбар/TabBar
```typescript
height: vs(56),           // навбар
paddingHorizontal: scale(16),
// + insets.top для StatusBar area
```

### Bottom TabBar
```typescript
height: vs(56),           // высота без safeArea
// + insets.bottom автоматически
```

## Квадратные элементы (аватары, иконки)

```typescript
// Для квадратных элементов используй одну функцию для обеих сторон:

// Аватары — scale (привязаны к ширине контента)
width: scale(40),
height: scale(40),
borderRadius: scale(20),

// Иконки — ms (масштабируются как шрифт)
width: ms(24),
height: ms(24),

// НЕ МИКСУЙ: width: scale(40), height: vs(40) — получишь овал!
```

## Процентная ширина из Figma

```typescript
// Если в Figma элемент занимает часть ширины фрейма:
// Например: карточка 343px в фрейме 390px

// Вариант A — scale (предпочтительный)
width: scale(343),

// Вариант B — процент (если Figma явно показывает %)
width: '88%',  // 343 / 390 ≈ 88%

// Вариант C — flex (если fill container)
flex: 1,
marginHorizontal: scale(24),  // если отступы с двух сторон
```

## Скрытые grids в Figma

Если в Figma видна сетка (например 8-pt grid):
```typescript
// Все значения должны быть кратны 8 после scale()
// Проверяй: scale(8) = 8 * (screenWidth / 390)
// На iPhone 14 = 8pt * 1.0 = 8
// На iPhone SE (375) = 8 * (375/390) ≈ 7.7 → PixelRatio.roundToNearestPixel → 8
```

## Когда НЕ масштабировать

```
letterSpacing     → прямое значение из Figma
borderWidth       → 1 или 2 (прямое значение, StyleSheet.hairlineWidth для 1px линий)
opacity           → 0–1 (прямое значение)
zIndex            → целое число (прямое значение)
flex              → число (прямое значение)
aspectRatio       → число (прямое значение)
transform scale   → число (прямое значение)
```
