#!/bin/bash
# rn-pixel-perfect — setup script
# Копирует скилл в проект и настраивает Figma MCP

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_GLOBAL="$HOME/.claude/settings.json"

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   rn-pixel-perfect setup             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
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

# Раскрыть ~ в пути
TARGET_PROJECT="${TARGET_PROJECT/#\~/$HOME}"

if [ ! -d "$TARGET_PROJECT" ]; then
  echo -e "${RED}Директория не найдена: $TARGET_PROJECT${NC}"
  exit 1
fi

echo -e "${GREEN}Проект: $TARGET_PROJECT${NC}"
echo ""

# ─── 2. Копировать скилл ───
echo -e "${BLUE}[1/4] Копирую скилл в проект...${NC}"
mkdir -p "$TARGET_PROJECT/.claude/skills"
cp -r "$SKILL_DIR/.claude/skills/rn-pixel-perfect" "$TARGET_PROJECT/.claude/skills/"
echo -e "${GREEN}  ✓ Скилл скопирован в .claude/skills/rn-pixel-perfect/${NC}"

# ─── 3. Проверить Figma MCP (figma-mcp-go) ───
echo ""
echo -e "${BLUE}[2/4] Проверяю Figma MCP (figma-mcp-go)...${NC}"

MCP_CONFIGURED=false
if [ -f "$CLAUDE_GLOBAL" ]; then
  if grep -q '"figma-mcp-go"' "$CLAUDE_GLOBAL" 2>/dev/null; then
    MCP_CONFIGURED=true
    echo -e "${GREEN}  ✓ figma-mcp-go уже настроен в ~/.claude/settings.json${NC}"
  fi
fi

if [ "$MCP_CONFIGURED" = false ]; then
  echo -e "${YELLOW}  figma-mcp-go не найден. Настроим? (Y/n):${NC}"
  read -r SETUP_FIGMA

  if [[ ! "$SETUP_FIGMA" =~ ^[Nn]$ ]]; then
    mkdir -p "$HOME/.claude"

    python3 - "$CLAUDE_GLOBAL" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]

data = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        data = json.load(f)

if "mcpServers" not in data:
    data["mcpServers"] = {}

data["mcpServers"]["figma-mcp-go"] = {
    "command": "npx",
    "args": ["-y", "@vkhanhqui/figma-mcp-go"]
}

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

print("OK")
PYEOF
    echo -e "${GREEN}  ✓ figma-mcp-go настроен в ~/.claude/settings.json${NC}"
    echo ""
    echo -e "  ${YELLOW}Важно:${NC} для работы нужен Figma Desktop с запущенным плагином:"
    echo "  1. Figma Desktop → Plugins → Development → Import plugin from manifest"
    echo "  2. Скачай plugin.zip из https://github.com/vkhanhqui/figma-mcp-go"
    echo "  3. Запусти плагин в нужном Figma файле"
    echo ""
    echo "  API токен НЕ нужен — данные читаются через плагин, не через REST API."
    echo "  Rate limits НЕТ — вызовы бесплатные и безлимитные."
  else
    echo -e "${YELLOW}  ⚠ Figma MCP не настроен. Скилл будет работать без MCP.${NC}"
    echo ""
    echo "  Чтобы настроить позже, добавь в ~/.claude/settings.json:"
    echo '  "mcpServers": {'
    echo '    "figma-mcp-go": {'
    echo '      "command": "npx",'
    echo '      "args": ["-y", "@vkhanhqui/figma-mcp-go"]'
    echo '    }'
    echo '  }'
  fi
fi

# ─── 3.5. Установить MCP proxy для авто-перезапуска ───
echo ""
echo -e "${BLUE}[2.5/4] Настраиваю MCP proxy (авто-перезапуск при падении)...${NC}"

PROXY_DIR="$HOME/.claude/scripts"
PROXY_SRC="$SKILL_DIR/scripts/figma-mcp-proxy.js"
PROXY_DST="$PROXY_DIR/figma-mcp-proxy.js"

if [ -f "$PROXY_SRC" ]; then
  mkdir -p "$PROXY_DIR"
  cp "$PROXY_SRC" "$PROXY_DST"
  chmod +x "$PROXY_DST"
  echo -e "${GREEN}  ✓ Proxy установлен: $PROXY_DST${NC}"

  # Обновляем settings.json — переключаем figma-mcp-go на proxy
  if grep -q '"figma-mcp-go"' "$CLAUDE_GLOBAL" 2>/dev/null; then
    python3 - "$CLAUDE_GLOBAL" "$PROXY_DST" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]
proxy_path = sys.argv[2]

data = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        data = json.load(f)

figma_cfg = data.get("mcpServers", {}).get("figma-mcp-go", {})
if not figma_cfg:
    print("SKIP: no figma-mcp-go config found")
    sys.exit(0)

# Update to proxy (no API key needed for figma-mcp-go)
data["mcpServers"]["figma-mcp-go"] = {
    "command": "node",
    "args": [proxy_path]
}

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

print("OK: migrated to proxy")
PYEOF
    echo -e "${GREEN}  ✓ settings.json обновлён — figma-mcp-go теперь через proxy${NC}"
    echo -e "  Proxy автоматически перезапускает сервер при падении (до 10 раз)."
  fi
else
  echo -e "${YELLOW}  ⚠ figma-mcp-proxy.js не найден в $SKILL_DIR/scripts/${NC}"
fi

# ─── 4. Проверить iOS Simulator MCP ───
echo ""
echo -e "${BLUE}[3/4] Проверяю iOS Simulator MCP...${NC}"

SIMULATOR_MCP_CONFIGURED=false
if [ -f "$CLAUDE_GLOBAL" ]; then
  if grep -q '"mobile-mcp"' "$CLAUDE_GLOBAL" 2>/dev/null || grep -q '"ios-simulator"' "$CLAUDE_GLOBAL" 2>/dev/null; then
    SIMULATOR_MCP_CONFIGURED=true
    echo -e "${GREEN}  ✓ iOS Simulator MCP уже настроен${NC}"
  fi
fi

if [ "$SIMULATOR_MCP_CONFIGURED" = false ]; then
  echo -e "${YELLOW}  iOS Simulator MCP не найден.${NC}"
  echo "  Он нужен для Phase 5 — автоматической визуальной проверки."
  echo "  Скилл будет сравнивать скриншот симулятора с Figma-дизайном"
  echo "  и автоматически исправлять код до 99.9%+ совпадения."
  echo ""
  echo -e "${YELLOW}  Добавить iOS Simulator MCP? (y/N):${NC}"
  read -r ADD_SIMULATOR

  if [[ "$ADD_SIMULATOR" =~ ^[Yy]$ ]]; then
    mkdir -p "$HOME/.claude"

    python3 - "$CLAUDE_GLOBAL" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]

data = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        data = json.load(f)

if "mcpServers" not in data:
    data["mcpServers"] = {}

data["mcpServers"]["mobile-mcp"] = {
    "command": "npx",
    "args": ["-y", "@mobilenext/mobile-mcp@latest"]
}

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

print("OK")
PYEOF
    echo -e "${GREEN}  ✓ iOS Simulator MCP настроен в ~/.claude/settings.json${NC}"
    echo ""
    echo "  Перед использованием загрузи симулятор:"
    echo -e "  ${BLUE}xcrun simctl boot \"iPhone 16\"${NC}"
  else
    echo -e "${YELLOW}  ⚠ iOS Simulator MCP не настроен.${NC}"
    echo "  Phase 5 (автоматическая визуальная проверка) будет пропущена."
    echo ""
    echo "  Чтобы настроить позже, добавь в ~/.claude/settings.json:"
    echo '  "mobile-mcp": {'
    echo '    "command": "npx",'
    echo '    "args": ["-y", "@mobilenext/mobile-mcp@latest"]'
    echo '  }'
  fi
fi

# ─── 5. Проверить зависимости проекта ───
echo ""
echo -e "${BLUE}[4/4] Проверяю зависимости проекта...${NC}"

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

    # Определяем менеджер пакетов
    if [ -f "$TARGET_PROJECT/bun.lockb" ] || [ -f "$TARGET_PROJECT/bun.lock" ]; then
      PKG_CMD="bun add"
    elif [ -f "$TARGET_PROJECT/yarn.lock" ]; then
      PKG_CMD="yarn add"
    elif [ -f "$TARGET_PROJECT/pnpm-lock.yaml" ]; then
      PKG_CMD="pnpm add"
    else
      PKG_CMD="npm install"
    fi

    # Проверяем Expo
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

# ─── Готово ───
echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Готово!                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo "  Теперь в Claude Code просто напиши:"
echo -e "  ${BLUE}Верстай HomeScreen по https://figma.com/design/...${NC}"
echo ""
