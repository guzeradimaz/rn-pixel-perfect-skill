# rn-pixel-perfect

Claude Code skill для pixel-perfect верстки React Native экранов из Figma.

## Что делает

Берёт ссылку на Figma → извлекает все значения через Figma MCP → генерирует React Native код с:
- `StyleSheet.create()` (без Tailwind, без NativeWind)
- `scale()` / `vs()` / `ms()` для адаптивности
- Semantic theme tokens (colors, typography, spacing, radius, shadows)
- `useSafeAreaInsets()` для всех экранов
- `Platform.select()` для шрифтов и теней
- `DebugOverlay` для визуальной проверки совпадения с дизайном

## Установка

### Быстрый старт (рекомендуется)
```bash
# Клонируй или скачай этот репозиторий, затем:
bash scripts/setup.sh /path/to/your-rn-project
```
Скрипт сам:
1. Скопирует скилл в проект
2. Проверит/настроит Figma MCP (попросит токен если нужно)
3. Проверит зависимости проекта

### Ручная установка

**В проект:**
```bash
cp -r .claude/ /path/to/your-rn-project/
```

**Глобально (для всех проектов):**
```bash
cp -r .claude/skills/rn-pixel-perfect ~/.claude/skills/
```

### Настройка Figma MCP

Добавь в `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "figma-developer-mcp"],
      "env": {
        "FIGMA_ACCESS_TOKEN": "YOUR_TOKEN"
      }
    }
  }
}
```
Токен получить: Figma → Settings → Personal Access Tokens → Generate new token.

После добавления — перезапусти Claude Code.

## Требования

1. **Figma MCP** — подключён и настроен (см. выше)
2. **react-native-safe-area-context** — установлен в проекте
3. Опционально: `react-native-svg` (если в Figma есть SVG-ассеты)

Скилл автоматически создаст недостающие файлы (`src/utils/scale.ts`, `src/theme/*`) из шаблонов при первом запуске.

## Использование

Просто давай задачи на верстку — скилл подхватится автоматически:

```
Верстай HomeScreen по https://figma.com/design/abc/App?node-id=1-2
```

```
Сверстай компонент карточки из Figma https://figma.com/design/abc/App?node-id=3-4
```

```
Обнови тему из Figma Variables https://figma.com/design/abc/App
```

```
Проверь совпадение с дизайном
```

Или просто вставь ссылку на Figma — скилл распознает и начнёт полный цикл.

## Рабочий процесс (4+1 фазы)

| Фаза | Что делает |
|------|-----------|
| **Phase 0** | Проверяет структуру проекта, создаёт недостающие файлы из шаблонов |
| **Phase 1** | Извлекает всё из Figma через MCP: размеры, цвета, типографику, тени |
| **Phase 2** | Синхронизирует токены дизайна → `src/theme/` |
| **Phase 3** | Верстает экран/компонент по правилам конвертации |
| **Phase 4** | Визуальная валидация через DebugOverlay + чеклист |

## Структура скилла

```
.claude/skills/rn-pixel-perfect/
  SKILL.md                          ← основной файл (читается Claude автоматически)
  references/
    scale-guide.md                  ← когда scale/vs/ms, типичные ошибки
    platform-patterns.md            ← iOS/Android: тени, шрифты, FlatList, Modal
    templates/
      scale.ts                      ← утилиты масштабирования
      colors.ts                     ← цветовые токены
      typography.ts                 ← типографика
      spacing.ts                    ← отступы
      radius.ts                     ← скругления
      shadows.ts                    ← кросс-платформенные тени
      index.ts                      ← barrel export темы
      DebugOverlay.tsx              ← оверлей для визуальной проверки
```

## Структура проекта после применения

```
src/
  screens/          ← экраны (HomeScreen.tsx, ProfileScreen.tsx)
  components/
    ui/             ← переиспользуемые атомы (Button, Input, Badge)
    {feature}/      ← компоненты фичи (ProfileCard, ProfileHeader)
  theme/
    colors.ts       ← семантические цвета из Figma
    typography.ts   ← стили текста
    spacing.ts      ← горизонтальные + вертикальные отступы
    radius.ts       ← скругления
    shadows.ts      ← тени iOS + Android
    index.ts        ← barrel export
  utils/
    scale.ts        ← scale(), vs(), ms()
    DebugOverlay.tsx ← dev-only оверлей
  assets/
    figma/          ← скриншоты из Figma для DebugOverlay
```

## Правила конвертации (шпаргалка)

| Из Figma | В React Native | Функция |
|----------|---------------|---------|
| width, paddingH, marginH, gap, borderRadius | `scale(n)` | горизонталь |
| height, paddingV, marginV, top, bottom | `vs(n)` | вертикаль |
| fontSize, lineHeight, icon size | `ms(n)` | умеренный |
| letterSpacing, borderWidth, opacity | прямое значение | без масштабирования |
| HEX цвет | `colors.semantic.name` | только из темы |
| box-shadow | `getShadow('md')` | кросс-платформа |
