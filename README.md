# rn-pixel-perfect

Claude Code skill для pixel-perfect верстки React Native экранов из Figma.

Figma → извлекает значения через MCP → генерирует React Native код → проверяет в iOS Simulator до 99.9%+ совпадения.

Без API токена. Без rate limits. `StyleSheet.create()` only — без Tailwind/NativeWind.

## Установка

```bash
bash scripts/setup.sh /path/to/your-rn-project
```

Скрипт автоматически:
1. Скопирует скилл в проект
2. Скачает figma-mcp-go плагин с GitHub
3. Настроит MCP сервер + proxy (авто-перезапуск при падении)
4. Отключит официальный Figma MCP (API лимиты)
5. Настроит iOS Simulator MCP
6. Проверит зависимости

## Настройка Figma плагина (один раз)

Setup-скрипт скачивает плагин автоматически в `~/.claude/figma-plugin/`. Осталось импортировать в Figma:

1. Открой **Figma Desktop** (не браузер — плагин работает только в десктопе)
2. **Plugins → Development → Import plugin from manifest...**
3. Выбери `~/.claude/figma-plugin/manifest.json`

Готово — плагин появится в Plugins → Development → figma-mcp-go.

> Если скрипт не смог скачать автоматически — скачай [plugin.zip](https://github.com/vkhanhqui/figma-mcp-go/releases) вручную, распакуй в `~/.claude/figma-plugin/`.

## Перед каждой сессией верстки

1. Открой нужный **Figma файл** в Figma Desktop
2. **Plugins → Development → figma-mcp-go** → запусти
3. Окно плагина **оставь открытым** — через него идут данные
4. Перезапусти Claude Code (если первый раз после установки)

Статус плагина должен быть **Connected**. Если Disconnected — перезапусти Claude Code.

## Как верстать

Выдели фрейм в Figma и скажи:
```
Верстай выделенное
```

Или кинь ссылку:
```
Верстай HomeScreen по https://figma.com/design/abc/App?node-id=1-2
```

Или просто скажи что нужно:
```
Сверстай экран профиля
```

Другие команды:
```
Обнови тему из Figma Variables
Проверь совпадение с дизайном
Сверстай компонент карточки
```

## Ручная установка (без setup.sh)

**Скилл — в проект:**
```bash
cp -r .claude/ /path/to/your-rn-project/
```

**Proxy — глобально:**
```bash
mkdir -p ~/.claude/scripts
cp scripts/figma-mcp-proxy.js ~/.claude/scripts/
```

**MCP серверы — в `~/.claude/settings.json`:**
```json
{
  "mcpServers": {
    "figma-mcp-go": {
      "command": "node",
      "args": ["~/.claude/scripts/figma-mcp-proxy.js"]
    },
    "ios-simulator": {
      "command": "npx",
      "args": ["-y", "ios-simulator-mcp"]
    }
  }
}
```

**Отключи официальный Figma плагин** (бьёт по API лимитам):
```json
{
  "enabledPlugins": {
    "figma@claude-plugins-official": false
  }
}
```

**iOS Simulator** — загрузи перед использованием:
```bash
xcrun simctl boot "iPhone 16"
```

## Требования

- **Figma Desktop** с плагином figma-mcp-go
- **react-native-safe-area-context** в проекте
- **react-native-svg** (для SVG-иконок из Figma)
- **iOS Simulator MCP** для Phase 5 (визуальная проверка)

Скилл создаст `src/utils/scale.ts`, `src/theme/*` автоматически при первом запуске.
