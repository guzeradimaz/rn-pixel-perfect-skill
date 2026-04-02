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
- Экспорт иконок как SVG, изображений как PNG@2x/3x
- Без API rate limits — данные читаются через Figma плагин

## Установка

### Быстрый старт (рекомендуется)
```bash
# Клонируй или скачай этот репозиторий, затем:
bash scripts/setup.sh /path/to/your-rn-project
```
Скрипт сам:
1. Скопирует скилл в проект
2. Настроит figma-mcp-go + MCP proxy (авто-перезапуск при падении)
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

### Настройка Figma MCP (figma-mcp-go)

Скилл использует [figma-mcp-go](https://github.com/vkhanhqui/figma-mcp-go) — MCP сервер, который читает данные из Figma напрямую через плагин. **Без API токена. Без rate limits.**

#### Шаг 1 — Установи Figma плагин

1. Перейди на [github.com/vkhanhqui/figma-mcp-go/releases](https://github.com/vkhanhqui/figma-mcp-go/releases)
2. Скачай **plugin.zip** из последнего релиза
3. Распакуй архив в любую папку

#### Шаг 2 — Импортируй плагин в Figma Desktop

1. Открой **Figma Desktop** (не браузерную версию — плагин работает только в десктопном приложении)
2. Открой любой файл
3. В главном меню: **Plugins → Development → Import plugin from manifest...**
4. Выбери файл `manifest.json` из распакованной папки plugin

#### Шаг 3 — Запусти плагин

1. Открой Figma файл с дизайном, который будешь верстать
2. **Plugins → Development → figma-mcp-go**
3. Появится окно плагина — **оставь его открытым** на всё время работы
4. Плагин создаёт бридж между Figma и MCP сервером — через него идут все данные

> **Плагин должен быть запущен** пока Claude Code работает с Figma. Если закроешь — MCP перестанет получать данные.

#### Шаг 4 — Настрой MCP сервер

Добавь в `~/.claude/settings.json`:

**С proxy (рекомендуется — авто-перезапуск при падении):**
```json
{
  "mcpServers": {
    "figma-mcp-go": {
      "command": "node",
      "args": ["/Users/ИМЯ/.claude/scripts/figma-mcp-proxy.js"]
    }
  }
}
```
Установить proxy: `cp scripts/figma-mcp-proxy.js ~/.claude/scripts/`

**Без proxy (проще, но менее стабильно):**
```json
{
  "mcpServers": {
    "figma-mcp-go": {
      "command": "npx",
      "args": ["-y", "@vkhanhqui/figma-mcp-go"]
    }
  }
}
```

#### Шаг 5 — iOS Simulator MCP (для Phase 5)

```json
{
  "mcpServers": {
    "ios-simulator": {
      "command": "npx",
      "args": ["-y", "ios-simulator-mcp"]
    }
  }
}
```
Перед использованием загрузи симулятор: `xcrun simctl boot "iPhone 16"`

#### Шаг 6 — Перезапусти Claude Code

После изменения `settings.json` — перезапусти Claude Code чтобы MCP серверы подхватились.

> **Важно:** если ранее использовал официальный Figma MCP плагин (`figma@claude-plugins-official`), отключи его в settings.json:
> ```json
> "enabledPlugins": {
>   "figma@claude-plugins-official": false
> }
> ```
> Иначе он будет бить по Figma REST API с rate limits параллельно с figma-mcp-go.

## Требования

1. **Figma Desktop** — с запущенным плагином figma-mcp-go (см. выше)
2. **figma-mcp-go MCP** — настроен в settings.json
3. **iOS Simulator MCP** — для автоматической визуальной проверки (Phase 5)
4. **react-native-safe-area-context** — установлен в проекте
5. Опционально: `react-native-svg` (для SVG-иконок из Figma)

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
