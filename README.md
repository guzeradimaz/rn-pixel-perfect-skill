# rn-pixel-perfect

Claude Code skill для pixel-perfect верстки React Native экранов из Figma.

## Что делает

Берёт ссылку на Figma → извлекает все значения через Figma MCP → генерирует React Native код → автоматически проверяет в iOS Simulator до 99.9%+ совпадения с дизайном.

- `StyleSheet.create()` (без Tailwind, без NativeWind)
- `scale()` / `vs()` / `ms()` для адаптивности
- Semantic theme tokens (colors, typography, spacing, radius, shadows)
- `useSafeAreaInsets()` для всех экранов
- `Platform.select()` для шрифтов и теней
- **Автоматический visual validation loop** — сравнивает скриншот симулятора с Figma, исправляет код и повторяет до pixel-perfect
- Figma API rate limit стратегия — максимум 2-3 запроса на экран

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

### Настройка MCP серверов

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
    },
    "mobile-mcp": {
      "command": "npx",
      "args": ["-y", "@mobilenext/mobile-mcp@latest"]
    }
  }
}
```

- **Figma token:** Figma → Settings → Personal Access Tokens → Generate new token
- **iOS Simulator:** перед использованием загрузи: `xcrun simctl boot "iPhone 16"`

После добавления — перезапусти Claude Code.

## Требования

1. **Figma MCP** — подключён и настроен (см. выше)
2. **iOS Simulator MCP** — для автоматической визуальной проверки (Phase 5)
3. **react-native-safe-area-context** — установлен в проекте
4. Опционально: `react-native-svg` (если в Figma есть SVG-ассеты)

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

## Рабочий процесс (5+1 фаз)

| Фаза | Что делает |
|------|-----------|
| **Phase 0** | Проверяет структуру проекта, MCP серверы, создаёт недостающие файлы |
| **Phase 1** | Извлекает всё из Figma через MCP (2-3 запроса макс), сохраняет скриншот локально |
| **Phase 2** | Синхронизирует токены дизайна → `src/theme/` |
| **Phase 3** | Верстает экран/компонент по правилам конвертации |
| **Phase 4** | Аудит кода: проверка каждого значения против extraction map |
| **Phase 5** | **Visual loop:** скриншот симулятора vs Figma → правки → повтор до 99.9%+ совпадения |

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
