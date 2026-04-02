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
echo -e "${BLUE}[1/3] Копирую скилл в проект...${NC}"
mkdir -p "$TARGET_PROJECT/.claude/skills"
cp -r "$SKILL_DIR/.claude/skills/rn-pixel-perfect" "$TARGET_PROJECT/.claude/skills/"
echo -e "${GREEN}  ✓ Скилл скопирован в .claude/skills/rn-pixel-perfect/${NC}"

# ─── 3. Проверить Figma MCP ───
echo ""
echo -e "${BLUE}[2/3] Проверяю Figma MCP...${NC}"

MCP_CONFIGURED=false
if [ -f "$CLAUDE_GLOBAL" ]; then
  # Проверяем наличие figma в mcpServers
  if grep -q '"figma"' "$CLAUDE_GLOBAL" 2>/dev/null; then
    MCP_CONFIGURED=true
    echo -e "${GREEN}  ✓ Figma MCP уже настроен в ~/.claude/settings.json${NC}"
  fi
fi

if [ "$MCP_CONFIGURED" = false ]; then
  echo -e "${YELLOW}  Figma MCP не найден. Настроим?${NC}"
  echo ""
  echo "  Для работы нужен Figma Personal Access Token."
  echo "  Получить: Figma → Settings → Personal Access Tokens → Generate"
  echo ""
  echo -e "${YELLOW}  Вставь Figma Access Token (или Enter чтобы пропустить):${NC}"
  read -rs FIGMA_TOKEN
  echo ""

  if [ -n "$FIGMA_TOKEN" ]; then
    # Убедимся что ~/.claude/ существует
    mkdir -p "$HOME/.claude"

    # Единый скрипт: безопасно передаём токен через env, не через строковую интерполяцию
    FIGMA_TOKEN="$FIGMA_TOKEN" python3 - "$CLAUDE_GLOBAL" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]
token = os.environ["FIGMA_TOKEN"]

# Читаем существующий файл или создаём пустой объект
data = {}
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        data = json.load(f)

# Добавляем/обновляем Figma MCP
if "mcpServers" not in data:
    data["mcpServers"] = {}

data["mcpServers"]["figma"] = {
    "command": "npx",
    "args": ["-y", "figma-developer-mcp"],
    "env": {"FIGMA_ACCESS_TOKEN": token}
}

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

print("OK")
PYEOF
    echo -e "${GREEN}  ✓ Figma MCP настроен в ~/.claude/settings.json${NC}"
  else
    echo -e "${YELLOW}  ⚠ Figma MCP не настроен. Скилл будет работать без MCP,${NC}"
    echo -e "${YELLOW}    но не сможет читать данные из Figma автоматически.${NC}"
    echo ""
    echo "  Чтобы настроить позже, добавь в ~/.claude/settings.json:"
    echo '  "mcpServers": {'
    echo '    "figma": {'
    echo '      "command": "npx",'
    echo '      "args": ["-y", "figma-developer-mcp"],'
    echo '      "env": { "FIGMA_ACCESS_TOKEN": "YOUR_TOKEN" }'
    echo '    }'
    echo '  }'
  fi
fi

# ─── 4. Проверить зависимости проекта ───
echo ""
echo -e "${BLUE}[3/3] Проверяю зависимости проекта...${NC}"

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
