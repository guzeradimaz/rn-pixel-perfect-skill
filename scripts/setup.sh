#!/bin/bash
# rn-pixel-perfect — setup script
# Копирует скилл, скачивает figma-mcp-go плагин, настраивает MCP серверы

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_GLOBAL="$HOME/.claude/settings.json"
PLUGIN_DIR="$HOME/.claude/figma-plugin"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   rn-pixel-perfect setup                 ║${NC}"
echo -e "${BLUE}║   figma-mcp-go + proxy + iOS Simulator   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Определить целевой проект ───
TARGET_PROJECT=""
if [ -n "$1" ]; then
  TARGET_PROJECT="$1"
else
  echo -e "${YELLOW}Укажи путь к React Native проекту (или Enter для текущей директории):${NC}"
  read -r TARGET_PROJECT
  if [ -z "$TARGET_PROJECT" ]; then
    TARGET_PROJECT="$(pwd)"
  fi
fi

TARGET_PROJECT="${TARGET_PROJECT/#\~/$HOME}"

if [ ! -d "$TARGET_PROJECT" ]; then
  echo -e "${RED}Директория не найдена: $TARGET_PROJECT${NC}"
  exit 1
fi

echo -e "${GREEN}Проект: $TARGET_PROJECT${NC}"
echo ""

# ─── 2. Копировать скилл ───
echo -e "${BLUE}[1/6] Копирую скилл в проект...${NC}"
mkdir -p "$TARGET_PROJECT/.claude/skills"
cp -r "$SKILL_DIR/.claude/skills/rn-pixel-perfect" "$TARGET_PROJECT/.claude/skills/"
echo -e "${GREEN}  ✓ Скилл скопирован в .claude/skills/rn-pixel-perfect/${NC}"

# ─── 3. Скачать figma-mcp-go плагин ───
echo ""
echo -e "${BLUE}[2/6] Скачиваю figma-mcp-go плагин...${NC}"

PLUGIN_DOWNLOADED=false

if [ -d "$PLUGIN_DIR" ] && [ -f "$PLUGIN_DIR/manifest.json" ]; then
  echo -e "${GREEN}  ✓ Плагин уже установлен: $PLUGIN_DIR${NC}"
  PLUGIN_DOWNLOADED=true
else
  # Получаем URL последнего релиза через GitHub API
  echo "  Загружаю последний релиз с GitHub..."
  RELEASE_JSON=$(curl -s "https://api.github.com/repos/vkhanhqui/figma-mcp-go/releases/latest" 2>/dev/null || echo "")

  if [ -z "$RELEASE_JSON" ] || echo "$RELEASE_JSON" | grep -q '"message"'; then
    # Fallback: попробовать без /latest (может быть prerelease)
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/vkhanhqui/figma-mcp-go/releases" 2>/dev/null | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)[0]))" 2>/dev/null || echo "")
  fi

  PLUGIN_URL=""
  if [ -n "$RELEASE_JSON" ]; then
    PLUGIN_URL=$(echo "$RELEASE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assets = data.get('assets', [])
for a in assets:
    name = a.get('name', '')
    if 'plugin' in name.lower() and name.endswith('.zip'):
        print(a['browser_download_url'])
        break
" 2>/dev/null || echo "")
  fi

  if [ -n "$PLUGIN_URL" ]; then
    TMP_ZIP="/tmp/figma-mcp-go-plugin.zip"
    echo "  URL: $PLUGIN_URL"
    curl -sL "$PLUGIN_URL" -o "$TMP_ZIP"

    if [ -f "$TMP_ZIP" ] && [ -s "$TMP_ZIP" ]; then
      mkdir -p "$PLUGIN_DIR"
      unzip -qo "$TMP_ZIP" -d "$PLUGIN_DIR"
      rm -f "$TMP_ZIP"

      # Если manifest.json в подпапке — перемести наверх
      if [ ! -f "$PLUGIN_DIR/manifest.json" ]; then
        MANIFEST=$(find "$PLUGIN_DIR" -name "manifest.json" -maxdepth 3 | head -1)
        if [ -n "$MANIFEST" ]; then
          MANIFEST_PARENT=$(dirname "$MANIFEST")
          if [ "$MANIFEST_PARENT" != "$PLUGIN_DIR" ]; then
            mv "$MANIFEST_PARENT"/* "$PLUGIN_DIR/" 2>/dev/null || true
          fi
        fi
      fi

      if [ -f "$PLUGIN_DIR/manifest.json" ]; then
        PLUGIN_DOWNLOADED=true
        echo -e "${GREEN}  ✓ Плагин скачан и распакован: $PLUGIN_DIR${NC}"
      else
        echo -e "${RED}  ✗ manifest.json не найден в архиве${NC}"
      fi
    else
      echo -e "${RED}  ✗ Не удалось скачать plugin.zip${NC}"
    fi
  else
    echo -e "${YELLOW}  ⚠ Не удалось получить URL плагина из GitHub API${NC}"
    echo "  Скачай вручную: https://github.com/vkhanhqui/figma-mcp-go/releases"
    echo "  Распакуй plugin.zip в: $PLUGIN_DIR"
  fi
fi

# ─── 4. Настроить figma-mcp-go MCP + proxy ───
echo ""
echo -e "${BLUE}[3/6] Настраиваю figma-mcp-go MCP сервер...${NC}"

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/scripts"

# Копируем proxy
PROXY_SRC="$SKILL_DIR/scripts/figma-mcp-proxy.js"
PROXY_DST="$HOME/.claude/scripts/figma-mcp-proxy.js"
if [ -f "$PROXY_SRC" ]; then
  cp "$PROXY_SRC" "$PROXY_DST"
  chmod +x "$PROXY_DST"
  echo -e "${GREEN}  ✓ Proxy установлен: $PROXY_DST${NC}"
fi

# Обновляем settings.json
python3 - "$CLAUDE_GLOBAL" "$PROXY_DST" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]
proxy_path = sys.argv[2]

data = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        data = json.load(f)

if "mcpServers" not in data:
    data["mcpServers"] = {}

# Настраиваем figma-mcp-go через proxy
data["mcpServers"]["figma-mcp-go"] = {
    "command": "node",
    "args": [proxy_path]
}

# Удаляем старый figma-developer-mcp если есть
if "figma" in data.get("mcpServers", {}):
    old = data["mcpServers"]["figma"]
    # Только если это старый figma-developer-mcp, не что-то другое
    args = old.get("args", [])
    cmd = old.get("command", "")
    if "figma-developer-mcp" in str(args) or "figma-developer-mcp" in cmd:
        del data["mcpServers"]["figma"]
        print("Removed old figma-developer-mcp")

# Отключаем официальный Figma плагин (бьёт по API лимитам)
plugins = data.get("enabledPlugins", {})
if plugins.get("figma@claude-plugins-official"):
    plugins["figma@claude-plugins-official"] = False
    print("Disabled figma@claude-plugins-official (API rate limits)")

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

print("OK: figma-mcp-go configured with proxy")
PYEOF
echo -e "${GREEN}  ✓ figma-mcp-go настроен в ~/.claude/settings.json (через proxy)${NC}"
echo "  Proxy автоматически перезапускает сервер при падении (до 10 раз)."

# ─── 5. iOS Simulator MCP ───
echo ""
echo -e "${BLUE}[4/6] Проверяю iOS Simulator MCP...${NC}"

SIMULATOR_MCP_CONFIGURED=false
if [ -f "$CLAUDE_GLOBAL" ]; then
  if grep -q '"mobile-mcp"' "$CLAUDE_GLOBAL" 2>/dev/null || grep -q '"ios-simulator"' "$CLAUDE_GLOBAL" 2>/dev/null; then
    SIMULATOR_MCP_CONFIGURED=true
    echo -e "${GREEN}  ✓ iOS Simulator MCP уже настроен${NC}"
  fi
fi

if [ "$SIMULATOR_MCP_CONFIGURED" = false ]; then
  echo -e "${YELLOW}  iOS Simulator MCP не найден.${NC}"
  echo "  Нужен для Phase 5 — автоматической визуальной проверки (скриншот симулятора vs Figma)."
  echo ""
  echo -e "${YELLOW}  Добавить iOS Simulator MCP? (Y/n):${NC}"
  read -r ADD_SIMULATOR

  if [[ ! "$ADD_SIMULATOR" =~ ^[Nn]$ ]]; then
    python3 - "$CLAUDE_GLOBAL" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]

data = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        data = json.load(f)

if "mcpServers" not in data:
    data["mcpServers"] = {}

data["mcpServers"]["ios-simulator"] = {
    "command": "npx",
    "args": ["-y", "ios-simulator-mcp"]
}

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

print("OK")
PYEOF
    echo -e "${GREEN}  ✓ iOS Simulator MCP настроен${NC}"
    echo -e "  Перед использованием загрузи симулятор: ${BLUE}xcrun simctl boot \"iPhone 16\"${NC}"
  else
    echo -e "${YELLOW}  ⚠ Пропущено. Phase 5 будет недоступна.${NC}"
  fi
fi

# ─── 6. Проверить зависимости проекта ───
echo ""
echo -e "${BLUE}[5/6] Проверяю зависимости проекта...${NC}"

if [ -f "$TARGET_PROJECT/package.json" ]; then
  MISSING_DEPS=""

  if ! grep -q '"react-native-safe-area-context"' "$TARGET_PROJECT/package.json" 2>/dev/null; then
    MISSING_DEPS="$MISSING_DEPS react-native-safe-area-context"
  fi

  if ! grep -q '"react-native-svg"' "$TARGET_PROJECT/package.json" 2>/dev/null; then
    MISSING_DEPS="$MISSING_DEPS react-native-svg"
  fi

  if [ -n "$MISSING_DEPS" ]; then
    echo -e "${YELLOW}  ⚠ Не найдены зависимости:${MISSING_DEPS}${NC}"

    if [ -f "$TARGET_PROJECT/bun.lockb" ] || [ -f "$TARGET_PROJECT/bun.lock" ]; then
      PKG_CMD="bun add"
    elif [ -f "$TARGET_PROJECT/yarn.lock" ]; then
      PKG_CMD="yarn add"
    elif [ -f "$TARGET_PROJECT/pnpm-lock.yaml" ]; then
      PKG_CMD="pnpm add"
    else
      PKG_CMD="npm install"
    fi

    if grep -q '"expo"' "$TARGET_PROJECT/package.json" 2>/dev/null; then
      echo -e "  Установи: ${GREEN}npx expo install$MISSING_DEPS${NC}"
    else
      echo -e "  Установи: ${GREEN}$PKG_CMD$MISSING_DEPS${NC}"
    fi
  else
    echo -e "${GREEN}  ✓ Все зависимости на месте${NC}"
  fi
else
  echo -e "${YELLOW}  ⚠ package.json не найден в $TARGET_PROJECT${NC}"
fi

# ─── 7. Финальные инструкции ───
echo ""
echo -e "${BLUE}[6/6] Финальная настройка Figma плагина...${NC}"
echo ""

if [ "$PLUGIN_DOWNLOADED" = true ]; then
  echo -e "${GREEN}  Плагин figma-mcp-go готов: $PLUGIN_DIR${NC}"
  echo ""
  echo -e "  ${YELLOW}Осталось импортировать плагин в Figma Desktop (один раз):${NC}"
  echo ""
  echo "  1. Открой Figma Desktop (не браузер!)"
  echo "  2. Меню: Plugins → Development → Import plugin from manifest..."
  echo -e "  3. Выбери файл: ${BLUE}$PLUGIN_DIR/manifest.json${NC}"
  echo "  4. Готово — плагин появится в Plugins → Development → figma-mcp-go"
  echo ""
  echo -e "  ${YELLOW}Перед каждой сессией верстки:${NC}"
  echo "  • Открой нужный Figma файл"
  echo "  • Plugins → Development → figma-mcp-go → запусти"
  echo "  • Оставь окно плагина открытым"
else
  echo -e "${YELLOW}  Плагин нужно установить вручную:${NC}"
  echo "  1. Скачай plugin.zip: https://github.com/vkhanhqui/figma-mcp-go/releases"
  echo "  2. Распакуй в: $PLUGIN_DIR"
  echo "  3. Figma Desktop → Plugins → Development → Import plugin from manifest"
  echo "  4. Выбери $PLUGIN_DIR/manifest.json"
fi

# ─── Готово ───
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Готово!                                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  После импорта плагина в Figma — перезапусти Claude Code."
echo ""
echo "  Как верстать:"
echo -e "  ${BLUE}1. Выдели фрейм в Figma → \"Верстай выделенное\"${NC}"
echo -e "  ${BLUE}2. Вставь ссылку → \"Верстай HomeScreen по https://figma.com/...\"${NC}"
echo -e "  ${BLUE}3. Просто скажи → \"Сверстай экран профиля\"${NC}"
echo ""
echo "  Без API токена. Без rate limits. Безлимитные вызовы."
echo ""
