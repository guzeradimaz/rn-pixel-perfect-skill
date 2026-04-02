---
name: rn-pixel-perfect
description: >
  Pixel-perfect React Native UI from Figma. Use when: implementing Figma screens
  in React Native, converting design tokens to RN theme, verifying visual accuracy,
  or when user mentions "pixel perfect", "верстай экран", "по фигме", "match design",
  "сверстай", "UI из фигмы", "figma to react native".
  Reads Figma design values (px, colors, typography) via MCP and outputs pure
  StyleSheet.create() with scale(), theme tokens, SafeArea, and Platform-specific code.
  NO Tailwind. NO NativeWind. NO hardcode.
---

# RN Pixel Perfect Skill

Autonomous workflow: Figma URL → pixel-perfect React Native screen.
Integrates with Figma MCP. Reads design values directly from Figma (px, colors, typography).
Outputs pure `StyleSheet.create({})` with `scale()`, `vs()`, `ms()`, theme tokens.
**NO Tailwind. NO NativeWind. NO hardcoded values.**

### Reference files (read when needed)
This skill has additional reference files. Read them when the situation applies:
- `references/scale-guide.md` — read when unsure about scale()/vs()/ms() usage, edge cases, or common mistakes
- `references/platform-patterns.md` — read when implementing: shadows, fonts, SafeArea, FlatList, Modal, animations, gradients, or any platform-specific code

To find these files, search for `scale-guide.md` or `platform-patterns.md` in the project's `.claude/skills/` directory or in `~/.claude/skills/`.

### Template files (for Phase 0 scaffolding)
Templates are in `references/templates/` next to the reference files above.
Search for the skill directory to locate them:
- Look in `{projectRoot}/.claude/skills/rn-pixel-perfect/references/templates/`
- Or in `~/.claude/skills/rn-pixel-perfect/references/templates/`

---

## QUICK REFERENCE

```
scale(n)   → horizontal sizes (width, paddingH, marginH, borderRadius, gap)
vs(n)      → vertical sizes (height, paddingV, marginV, top, bottom)
ms(n)      → fonts and icons (moderate scale, factor 0.5)
colors.*   → ALL colors from src/theme/colors.ts
typography → font presets from src/theme/typography.ts
spacing.*  → horizontal spacing from src/theme/spacing.ts
vSpacing.* → vertical spacing from src/theme/spacing.ts
radius.*   → border radii from src/theme/radius.ts
getShadow  → cross-platform shadows from src/theme/shadows.ts
```

**FORBIDDEN:** hardcode px · Tailwind/NativeWind · className · inline styles · hex colors · useSafeAreaInsets omission · scale for letterSpacing/borderWidth/opacity

---

## FIGMA MCP SERVER: figma-mcp-go

> This skill uses `@vkhanhqui/figma-mcp-go` — a Figma MCP server that reads data
> directly via a **Figma Desktop plugin bridge**, NOT through the REST API.
> **No API key needed. No rate limits.** Calls are free and unlimited.

### Prerequisites
1. **Figma Desktop app** must be running (not web version)
2. **figma-mcp-go plugin** installed and active in the open Figma file:
   - Plugins → Development → Import plugin from manifest
   - Select `manifest.json` from the plugin.zip
   - Run the plugin inside the target Figma file
3. MCP server configured in `~/.claude/settings.json` (see Step 0.0)

### Available tools

| Category | Tool | Description |
|----------|------|-------------|
| **Primary** | `get_design_context` | Depth-limited tree — layout, colors, typography, spacing |
| **Primary** | `get_screenshot` | Base64 image export of any node |
| **Tokens** | `get_variable_defs` | Variable collections and values |
| **Extra** | `get_document` | Full current page tree |
| **Extra** | `get_metadata` | File name, pages, current page |
| **Extra** | `get_node` | Single node by ID |
| **Extra** | `get_nodes_info` | Multiple nodes by ID |
| **Extra** | `get_selection` | Currently selected nodes in Figma |
| **Extra** | `scan_text_nodes` | All text nodes in a subtree |
| **Extra** | `scan_nodes_by_types` | Nodes matching given type list |
| **Extra** | `get_styles` | Paint, text, effect, and grid styles |
| **Extra** | `get_local_components` | All components in the file |
| **Extra** | `get_annotations` | Dev-mode annotations |
| **Export** | `save_screenshots` | Export images to disk (no API call) |

### Call strategy (no rate limits, but be efficient)

There are **no rate limits**, but extract maximum data per call to reduce context window noise.

1. **ONE call to `get_design_context` for the root node FIRST.** Extract everything: layout, colors, fonts, spacing, children hierarchy. Write the extraction map immediately.
2. **Fetch child nodes freely if data is incomplete.** Unlike API-based servers, additional calls are free. But avoid unnecessary calls that bloat your context.
3. **`get_screenshot` — call for root node + any section needed for Phase 5.** Free to call multiple times.
4. **`get_variable_defs` — call when you need design tokens.** No cost, but only call if colors/typography reference variable names.
5. **Use `get_selection` when user says "верстай выделенное" / "implement selected".** Gets the currently selected nodes in Figma without needing a node ID.
6. **NEVER re-fetch data you already have.** The extraction map from Step 1.2 is your cache. Even without rate limits, re-fetching wastes context.
7. **Batch your planning.** Before any MCP call, plan what data you need. Make the call and extract all answers at once.

### Call sequence

```
CALL 1: get_design_context(fileKey, rootNodeId)
        → Extract EVERYTHING: layout, colors, fonts, spacing, children
        → Fill the complete extraction map
        → Decide: is any section missing?

CALL 2 (if needed): get_design_context(fileKey, childNodeId)
        → For sections truncated/missing in Call 1
        → Merge into extraction map

CALL 3: get_screenshot(fileKey, rootNodeId)
        → For Phase 5 visual validation
        → Save locally, reuse forever

CALL 4 (if needed): get_variable_defs(fileKey)
        → For theme token sync
```

**Typical screen: 3-4 calls. No hard limit, but stay efficient.**

---

## PHASE 0 — PROJECT SCAFFOLDING

> Before any coding, verify the project has everything needed.

### Step 0.0 — Check Figma MCP availability
Before calling any Figma tools, verify the MCP is available:
1. Try calling any Figma MCP tool (e.g., `get_metadata`)
2. If the tool is NOT available (error "tool not found" or similar):
   - Tell the user: "Figma MCP не подключён. Нужен `figma-mcp-go`:"
   a. Добавь в `~/.claude/settings.json` (с proxy для авто-перезапуска):
   ```json
   "mcpServers": {
     "figma-mcp-go": {
       "command": "node",
       "args": ["~/.claude/scripts/figma-mcp-proxy.js"]
     }
   }
   ```
   Установить proxy: `cp scripts/figma-mcp-proxy.js ~/.claude/scripts/`

   b. Или напрямую (без proxy):
   ```json
   "figma-mcp-go": {
     "command": "npx",
     "args": ["-y", "@vkhanhqui/figma-mcp-go"]
   }
   ```
   c. **Обязательно:** открой Figma Desktop → Plugins → Development → Import plugin from manifest → запусти плагин figma-mcp-go в файле
   d. Restart Claude Code for MCP to load
3. If tool responds but with **"plugin not connected"** or empty data:
   - Figma Desktop не запущена или плагин не активен
   - Tell user: "Открой Figma Desktop и запусти плагин figma-mcp-go в нужном файле"
4. If the MCP IS available and returns data — proceed to Step 0.0.1

### Step 0.0.1 — Check iOS Simulator MCP availability
Check if the `mobile-mcp` (or `ios-simulator`) MCP is available:
1. Try calling `mobile_take_screenshot` or `screenshot` tool
2. If NOT available — tell the user:
   > "iOS Simulator MCP не подключён. Без него Phase 5 (автоматическая визуальная проверка) будет пропущена. Запусти `bash scripts/setup.sh` или добавь вручную:"
   ```json
   "mcpServers": {
     "mobile-mcp": {
       "command": "npx",
       "args": ["-y", "@mobilenext/mobile-mcp@latest"]
     }
   }
   ```
   - Перед использованием загрузи симулятор: `xcrun simctl boot "iPhone 16"`
3. If available — set `simulatorMCP = true` (enables Phase 5 visual loop)
4. **Phase 5 is MANDATORY when simulator MCP is available.** The implementation is NOT complete until visual validation passes.

### Step 0.0.2 — MCP Server Resilience (applies to ALL phases)

> `figma-mcp-go` is a local stdio process that may crash mid-session.
> The MCP proxy auto-restarts it, but if that fails — follow recovery below.

#### Error classification:
| Error type | Symptoms | Action |
|-----------|----------|--------|
| **Server Crash** | "MCP server disconnected", "connection reset", timeout, "tool not available" after it WAS working | → Recovery below |
| **Plugin Disconnected** | MCP responds but returns empty/no data | → Tell user to restart plugin in Figma Desktop |
| **Not Configured** | "tool not found" on very first call | → Step 0.0 |

#### Recovery protocol (on MCP crash during ANY phase):
1. **Detect:** Figma MCP call fails with connection/server error
2. **Retry once:** Wait 3 seconds, try the SAME call again
   - MCP proxy (if installed) will auto-restart the server in background
3. **If retry succeeds:** Continue normally. Note: "MCP recovered after crash."
4. **If retry fails:**
   a. Tell user: "Figma MCP сервер упал. Проверь `/mcp` и перезапусти. Также убедись, что плагин figma-mcp-go запущен в Figma Desktop."
   b. **Do NOT block work.** Continue with cached data:
      - Extraction map exists → use it for all implementation
      - Figma screenshot saved locally → use it for visual comparison
      - Phase 5 (simulator) works WITHOUT Figma MCP (all local files)
   c. After user restarts MCP → verify with a test call before resuming

#### Prevention — MCP proxy (recommended):
Auto-restart on crash via proxy wrapper:
```json
"figma-mcp-go": {
  "command": "node",
  "args": ["~/.claude/scripts/figma-mcp-proxy.js"]
}
```
Install: `cp scripts/figma-mcp-proxy.js ~/.claude/scripts/`
The proxy restarts `@vkhanhqui/figma-mcp-go` automatically (up to 10 times with backoff) and replays MCP init handshake — Claude Code never sees the interruption. No API key needed.

### Step 0.1 — Detect existing structure
Check which of these files exist in the project:
```
src/utils/scale.ts          ← scale(), vs(), ms()
src/utils/DebugOverlay.tsx  ← dev overlay for visual comparison
src/theme/colors.ts         ← semantic color tokens
src/theme/typography.ts     ← text style presets
src/theme/spacing.ts        ← spacing tokens
src/theme/radius.ts         ← border radius tokens
src/theme/shadows.ts        ← cross-platform shadow utility
src/theme/index.ts          ← barrel export
```

### Step 0.2 — Create missing files from templates
For every missing file above, copy the template from this skill's `references/templates/` directory.
Adapt imports to match the project's path alias (`@/`, `~/`, `../`, etc.).

**If the project uses a different path alias** (e.g., `~/` instead of `@/`):
- Update all template imports accordingly
- Check `tsconfig.json` → `paths` or `babel.config.js` → `module-resolver` for the alias

### Step 0.3 — Verify dependencies
Check `package.json` for:
- `react-native-safe-area-context` — REQUIRED (SafeArea insets)
- `react-native-svg` — needed if Figma has SVG assets

If missing, inform the user but do NOT auto-install. Say:
> "Для корректной работы нужно установить: `npx expo install react-native-safe-area-context`"

### Step 0.4 — Detect BASE_WIDTH
If the project already has `scale.ts`, read the current `BASE_WIDTH`.
It will be updated in Phase 1 if the Figma frame width differs.

---

## PHASE 1 — FIGMA RECONNAISSANCE

> **Minimize Figma API calls.** Follow the Rate Limit Strategy above.
> Goal: extract ALL data in 2-3 calls max, then never re-fetch.
> If the user just pastes a Figma link — start from Phase 0, then Phase 1 automatically.

### Step 1.1 — Parse URL
Extract `fileKey` and `nodeId` from the Figma URL:
```
https://figma.com/design/{fileKey}/Name?node-id={nodeId}
https://www.figma.com/file/{fileKey}/Name?node-id={nodeId}
https://figma.com/proto/{fileKey}/Name?node-id={nodeId}
```
Node IDs in URLs use `-` as separator (e.g., `1-2`), but the MCP may need `:` format (e.g., `1:2`).
Try both formats if one fails.

### Step 1.2 — Get design context (THE PRIMARY CALL)
```
get_design_context(fileKey, nodeId)
```
**This is your most important and often ONLY Figma call.** Make it count.

The MCP returns layout, spacing, colors, typography, and component hierarchy.
The MCP may return React + Tailwind code — **IGNORE the Tailwind classes**, use only raw px values.

**CRITICAL: Immediately write down a COMPLETE extraction map.**
Go through the ENTIRE response and extract EVERY value into this JSON structure.
This is your single source of truth and your CACHE — you will NOT re-fetch this data.

```json
{
  "screen": "{ScreenName}",
  "frame": { "width": 390, "height": 844 },
  "figmaCalls": { "used": 1, "budget": 5 },
  "components": [
    {
      "name": "Header",
      "figmaNodeId": "1:23",
      "layout": {
        "width": 390, "height": 56,
        "paddingH": 16, "paddingV": 12,
        "flexDirection": "row",
        "justifyContent": "space-between",
        "alignItems": "center",
        "gap": 8
      },
      "typography": {
        "fontSize": 18, "lineHeight": 24,
        "fontWeight": "600", "letterSpacing": -0.3,
        "fontFamily": "SF Pro Text"
      },
      "colors": {
        "background": "#FFFFFF",
        "text": "#000000"
      },
      "radius": 0,
      "shadow": null,
      "children": ["BackButton", "Title", "ActionButton"]
    }
  ]
}
```

**Rules for extraction:**
- Record EVERY px value exactly as Figma shows it — do not round or guess
- If a value seems ambiguous, make a reasonable inference from context (parent padding, sibling sizes) — do NOT immediately re-call MCP
- Mark truly missing critical values as `"INCOMPLETE"` — these are the ONLY reason to make another call
- Frame width ≠ 390 → update `BASE_WIDTH` in `scale.ts` BEFORE coding
- **Track your call count** in the extraction map `figmaCalls` field

### Step 1.3 — Assess: do you need more data?

After filling the extraction map, check:
- Are there `"INCOMPLETE"` values that block implementation? (not just nice-to-have)
- Are entire screen sections missing from the response?

**If YES** (truly blocking data is missing): make ONE additional `get_design_context` call for the largest missing section. Update the extraction map. Increment `figmaCalls.used`.

**If NO**: proceed to Phase 2. Do NOT make extra calls "just to be sure".

### Step 1.4 — Get screenshot and SAVE LOCALLY
```
get_screenshot(nodeIds: ["1:23"], format: "PNG", scale: 2)
```
Call this if:
- Phase 5 (visual validation loop) will be used (simulator MCP is available)
- The user explicitly asks for visual validation / DebugOverlay
- You're implementing a complex screen and need visual reference

**CRITICAL: Save the screenshot LOCALLY immediately.**
```
src/assets/figma/{ScreenName}_design.png
```
This local file is your **permanent reference image**. All future comparisons in Phase 5
use THIS LOCAL FILE — never re-fetch from Figma.

**One screenshot per screen, at the root node level only. Save once, reuse forever.**

### Step 1.4.1 — Export icons and images from Figma

> **This is where icons/images get downloaded.** Use the right format for each asset type.

#### Format rules:
| Asset type | Format | Scale | Why |
|-----------|--------|-------|-----|
| **Icons** (monochrome, simple shapes) | `SVG` | — | Vector, scales perfectly, tiny file size |
| **Icons** (if SVG fails or RN can't render) | `PNG` | `3` | @3x for all densities |
| **Illustrations** (complex vectors) | `SVG` | — | Vector quality at any size |
| **Photos / raster images** | `PNG` | `2` | Good quality/size balance |
| **Screen reference** (Phase 5) | `PNG` | `2` | For visual comparison only |

#### Using `save_screenshots` for batch export:
```
save_screenshots(items: [
  { nodeId: "1:23", outputPath: "src/assets/icons/home.svg", format: "SVG" },
  { nodeId: "1:24", outputPath: "src/assets/icons/search.svg", format: "SVG" },
  { nodeId: "1:25", outputPath: "src/assets/icons/profile.svg", format: "SVG" },
  { nodeId: "1:30", outputPath: "src/assets/images/hero.png", format: "PNG", scale: 2 }
])
```

#### Using `get_screenshot` for single export:
```
get_screenshot(nodeIds: ["1:23"], format: "SVG")
get_screenshot(nodeIds: ["1:24"], format: "PNG", scale: 3)
```

#### Key rules:
1. **Icons → ALWAYS try SVG first.** SVG renders crisply at any size, no @2x/@3x variants needed.
2. **If SVG export is broken** (complex effects, rasterized fills) → fallback to PNG with `scale: 3`
3. **Use `save_screenshots` for batch** — exports multiple assets in one call, saves to disk directly
4. **File naming:** lowercase, kebab-case: `icon-home.svg`, `img-hero.png`
5. **Save to correct folders:**
   ```
   src/assets/icons/    ← SVG and PNG icons
   src/assets/images/   ← photos, illustrations
   src/assets/figma/    ← design reference screenshots (Phase 5 only)
   ```
6. **Never use Figma image URLs in production code** — always download and use `require()`

### Step 1.5 — Get design tokens (ONLY if explicitly requested)
```
get_variable_defs(fileKey)
```
**Only call this if:**
- The user explicitly asks to sync Figma Variables / design tokens
- Colors in the design context reference variable names instead of hex values

Do NOT call this by default. Most implementations work fine with hex values from `get_design_context`.

### Step 1.6 — Handling Figma MCP errors

> figma-mcp-go has **no rate limits** (data via plugin bridge, not REST API).
> The main failure mode is **server crash or plugin disconnect**.

**A) Server crash / disconnect:**
If a Figma MCP call fails with connection error, timeout, or "server disconnected":
→ Follow the **recovery protocol** in Step 0.0.2 (retry once → continue with cached data → ask user to restart MCP if needed)

**B) Plugin not running / empty data:**
If MCP call succeeds but returns empty or "plugin not connected":
1. Tell user: "Figma плагин не подключён. Открой Figma Desktop и запусти figma-mcp-go плагин в нужном файле."
2. Wait for user confirmation, then retry

**C) Wrong file open in Figma:**
If data doesn't match the expected design (wrong nodes, missing sections):
1. Tell user: "Данные не совпадают — проверь, что в Figma открыт правильный файл и плагин запущен."

---

## PHASE 2 — TOKEN SYNC

After reconnaissance, update theme files if needed. Only update values that differ from Figma.

### Colors → src/theme/colors.ts
```typescript
// Map Figma hex → semantic token name
// NEVER use hex directly in components
export const colors = {
  primary: { default: '#...', pressed: '#...', disabled: '#...' },
  background: { primary: '#...', secondary: '#...', tertiary: '#...' },
  text: { primary: '#...', secondary: '#...', placeholder: '#...', inverse: '#...', disabled: '#...' },
  border: { default: '#...', focused: '#...' },
  status: { success: '#...', error: '#...', warning: '#...', info: '#...' },
} as const;
```

**If the project supports dark mode:**
```typescript
export const lightColors = { /* ... */ } as const;
export const darkColors = { /* ... */ } as const;

export type Colors = typeof lightColors;
export const colors = lightColors; // or use context-based switching
```

### Typography → src/theme/typography.ts
```typescript
import { Platform } from 'react-native';
import { ms } from '@/utils/scale';

export const typography = {
  h1: { fontSize: ms(32), lineHeight: ms(40), fontWeight: '700' as const,
        fontFamily: Platform.select({ ios: 'SF Pro Display', android: 'Roboto-Bold' }) },
  body1: { fontSize: ms(16), lineHeight: ms(24), fontWeight: '400' as const,
           fontFamily: Platform.select({ ios: 'SF Pro Text', android: 'Roboto' }) },
  // ... add all styles from Figma
};
```

### Spacing → src/theme/spacing.ts
Map Figma spacing values to semantic tokens using `scale()` and `vs()`.

### Radius → src/theme/radius.ts
Map Figma corner radius values to semantic tokens using `scale()`.

### Shadows → src/theme/shadows.ts
Update shadow levels if Figma has specific shadow specs:
- Extract blur, offset, color, spread from Figma
- Map to nearest level (sm/md/lg/xl) or add custom levels

---

## PHASE 3 — IMPLEMENTATION

### 3.1 Component breakdown
Before coding, decompose the screen from the extraction map (Phase 1):
```
Screen (layout + SafeArea + data wiring)
  ├── Header / NavigationBar
  ├── Content (ScrollView / FlatList / SectionList)
  │   ├── [Section]Card / [Section]Item
  │   ├── [Section]List
  │   └── ...
  ├── UI atoms: Button, Input, Badge, Avatar, Chip...
  └── Footer / BottomBar / TabBar
```
Create separate files for each. No monolithic screens.
Shared UI atoms go to `src/components/ui/`. Feature-specific components go to `src/components/{feature}/`.

### 3.1.1 Implementation order (CRITICAL for accuracy)
**Implement bottom-up: atoms first, then composites, then screen.**

1. **UI atoms** — smallest pieces (Button, Badge, Avatar, Icon)
2. **Composite components** — cards, list items, headers that use atoms
3. **Screen** — assembles composites with ScrollView/FlatList + SafeArea

For each component:
1. Look up its exact values from the extraction map (Phase 1 JSON)
2. Write the component using ONLY those values
3. Verify every StyleSheet property against the extraction map before moving on
4. Do NOT move to the next component until current one is done

**Why bottom-up?** Top-down causes "layout drift" — small errors in parent padding
compound with child spacing, making everything off by 4-8px by the bottom of the screen.

### 3.2 Figma → RN conversion table

| Figma property | React Native | Scale function |
|----------------|-------------|----------------|
| `width` in px | `width: scale(n)` | `scale` |
| `height` in px | `height: vs(n)` | `vs` |
| `padding-left/right` | `paddingHorizontal: scale(n)` | `scale` |
| `padding-top/bottom` | `paddingVertical: vs(n)` | `vs` |
| `margin-left/right` | `marginHorizontal: scale(n)` | `scale` |
| `margin-top/bottom` | `marginVertical: vs(n)` | `vs` |
| `font-size` | `fontSize: ms(n)` | `ms` |
| `line-height` | `lineHeight: ms(n)` | `ms` |
| `letter-spacing` | `letterSpacing: n` | **NO scale** (direct) |
| `border-width` | `borderWidth: n` | **NO scale** (direct, 1-2px) |
| `border-radius` | `borderRadius: scale(n)` | `scale` |
| `gap` (auto-layout) | `gap: scale(n)` | `scale` |
| `opacity` | `opacity: n` | **direct** (0–1) |
| HEX color | `colors.semantic.name` | from theme ONLY |
| `box-shadow` | `getShadow('sm'/'md'/'lg')` | Platform-aware |
| `position: absolute` | only if Figma uses absolute | justify explicitly |
| `auto layout → horizontal` | `flexDirection: 'row'` | + alignItems |
| `auto layout → vertical` | `flexDirection: 'column'` | default |
| `space-between` | `justifyContent: 'space-between'` | |
| `fill container` | `flex: 1` | |
| `hug content` | omit width/height | let content define |
| `fixed width/height` | `width: scale(n)` / `height: vs(n)` | explicitly set |

### 3.3 Screen template
```typescript
import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { scale, vs } from '@/utils/scale';
import { colors } from '@/theme/colors';

interface HomeScreenProps {}

export const HomeScreen: React.FC<HomeScreenProps> = () => {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[
          styles.content,
          { paddingBottom: insets.bottom + vs(16) },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* components here */}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background.primary,
  },
  scroll: {
    flex: 1,
  },
  content: {
    paddingHorizontal: scale(16),
    paddingTop: vs(24),
  },
});
```

### 3.4 FlatList screen template
```typescript
import React from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { scale, vs } from '@/utils/scale';
import { colors } from '@/theme/colors';

interface Item {
  id: string;
  // ... fields from Figma design
}

interface ListScreenProps {
  data: Item[];
}

export const ListScreen: React.FC<ListScreenProps> = ({ data }) => {
  const insets = useSafeAreaInsets();

  const renderItem = ({ item }: { item: Item }) => (
    <View style={styles.item}>
      {/* item content matching Figma card design */}
    </View>
  );

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <FlatList
        data={data}
        renderItem={renderItem}
        keyExtractor={(item) => item.id}
        contentContainerStyle={[
          styles.listContent,
          { paddingBottom: insets.bottom + vs(16) },
        ]}
        showsVerticalScrollIndicator={false}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background.primary,
  },
  listContent: {
    paddingHorizontal: scale(16),
    paddingTop: vs(16),
  },
  item: {
    // match Figma card/item design
  },
  separator: {
    height: vs(12),
  },
});
```

### 3.5 Component template
```typescript
import React from 'react';
import { StyleSheet, Text, TouchableOpacity } from 'react-native';
import { scale, vs, ms } from '@/utils/scale';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';
import { getShadow } from '@/theme/shadows';

interface ButtonProps {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  label,
  onPress,
  variant = 'primary',
  disabled = false,
}) => (
  <TouchableOpacity
    style={[styles.root, styles[variant], disabled && styles.disabled]}
    onPress={onPress}
    disabled={disabled}
    activeOpacity={0.8}
  >
    <Text style={[styles.label, disabled && styles.labelDisabled]}>
      {label}
    </Text>
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  root: {
    height: vs(52),
    borderRadius: scale(12),
    paddingHorizontal: scale(24),
    alignItems: 'center',
    justifyContent: 'center',
    ...getShadow('sm'),
  },
  primary: {
    backgroundColor: colors.primary.default,
  },
  secondary: {
    backgroundColor: colors.background.secondary,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  disabled: {
    backgroundColor: colors.primary.disabled,
  },
  label: {
    ...typography.button,
    color: colors.text.inverse,
  },
  labelDisabled: {
    color: colors.text.disabled,
  },
});
```

### 3.6 TextInput template
```typescript
import React, { useState } from 'react';
import { StyleSheet, TextInput as RNTextInput, View, Text } from 'react-native';
import { scale, vs, ms } from '@/utils/scale';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

interface InputProps {
  label?: string;
  placeholder?: string;
  value: string;
  onChangeText: (text: string) => void;
  error?: string;
}

export const Input: React.FC<InputProps> = ({
  label,
  placeholder,
  value,
  onChangeText,
  error,
}) => {
  const [focused, setFocused] = useState(false);

  return (
    <View style={styles.wrapper}>
      {label && <Text style={styles.label}>{label}</Text>}
      <RNTextInput
        style={[
          styles.input,
          focused && styles.inputFocused,
          error && styles.inputError,
        ]}
        placeholder={placeholder}
        placeholderTextColor={colors.text.placeholder}
        value={value}
        onChangeText={onChangeText}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
      />
      {error && <Text style={styles.error}>{error}</Text>}
    </View>
  );
};

const styles = StyleSheet.create({
  wrapper: {
    gap: vs(6),
  },
  label: {
    ...typography.body2,
    color: colors.text.secondary,
  },
  input: {
    height: vs(52),
    borderRadius: scale(10),
    borderWidth: 1,
    borderColor: colors.border.default,
    paddingHorizontal: scale(16),
    ...typography.body1,
    color: colors.text.primary,
    backgroundColor: colors.background.primary,
  },
  inputFocused: {
    borderColor: colors.border.focused,
  },
  inputError: {
    borderColor: colors.status.error,
  },
  error: {
    ...typography.caption,
    color: colors.status.error,
  },
});
```

### 3.7 Shadow pattern (cross-platform)
```typescript
import { getShadow } from '@/theme/shadows';

// In StyleSheet:
card: {
  ...getShadow('md'),
  backgroundColor: colors.background.primary, // REQUIRED for shadows
}
```

### 3.8 Font pattern (cross-platform)
```typescript
// Option A — use typography spread (preferred):
text: {
  ...typography.body1,
  color: colors.text.primary,
}

// Option B — manual Platform.select (when Figma uses non-standard font):
import { Platform } from 'react-native';
text: {
  fontSize: ms(16),
  lineHeight: ms(24),
  fontFamily: Platform.select({
    ios: 'CustomFont-Regular',
    android: 'CustomFont-Regular',
    default: 'System',
  }),
}
```

### 3.9 Using Figma assets in code

**SVG icons (preferred):**
```typescript
// react-native-svg required: npx expo install react-native-svg
import { SvgXml } from 'react-native-svg';

// Option A: import SVG as string (with metro transformer)
import HomeSvg from '@/assets/icons/icon-home.svg';
<HomeSvg width={scale(24)} height={scale(24)} fill={colors.textPrimary} />

// Option B: read SVG file content inline
const homeIcon = `<svg>...</svg>`;
<SvgXml xml={homeIcon} width={scale(24)} height={scale(24)} />
```

**PNG icons (fallback when SVG fails):**
```typescript
import { Image } from 'react-native';

<Image
  source={require('@/assets/icons/icon-home.png')}
  style={{ width: scale(24), height: scale(24) }}
  resizeMode="contain"
/>
```

**Photos / illustrations:**
```typescript
<Image
  source={require('@/assets/images/hero.png')}
  style={{ width: '100%', height: scale(200) }}
  resizeMode="cover"
/>
```

**NEVER use Figma URLs** — always use locally saved assets via `require()`.
Icons from Step 1.4.1 should already be in `src/assets/icons/` and `src/assets/images/`.

---

## PHASE 4 — SELF-REVIEW & VALIDATION

> This phase is MANDATORY. Do NOT skip it. Do NOT just say "looks good".
> Every value must be verified against the extraction map from Phase 1.

### 4.1 — Value-by-value audit (CRITICAL)
After ALL components are implemented, build a verification table.
Go through EVERY StyleSheet in EVERY generated file and compare each value
against the extraction map from Phase 1.

**Output this table in your response:**

```
VERIFICATION: {ComponentName}
┌─────────────────────┬──────────┬───────────────────┬────────┐
│ Property            │ Figma px │ Code              │ Status │
├─────────────────────┼──────────┼───────────────────┼────────┤
│ width               │ 343      │ scale(343)        │ ✓      │
│ height              │ 52       │ vs(52)            │ ✓      │
│ paddingHorizontal   │ 16       │ scale(16)         │ ✓      │
│ paddingVertical     │ 12       │ vs(12)            │ ✓      │
│ fontSize            │ 16       │ ms(16)            │ ✓      │
│ lineHeight          │ 24       │ ms(24)            │ ✓      │
│ letterSpacing       │ -0.3     │ -0.3              │ ✓      │
│ borderRadius        │ 12       │ scale(12)         │ ✓      │
│ gap                 │ 8        │ scale(8)          │ ✓      │
│ backgroundColor     │ #007AFF  │ colors.primary    │ ✓      │
│ color (text)        │ #FFFFFF  │ colors.text.inv.  │ ✓      │
│ fontWeight          │ 600      │ '600'             │ ✓      │
│ borderWidth         │ 1        │ 1 (direct)        │ ✓      │
│ shadow              │ blur:8   │ getShadow('md')   │ ✓      │
└─────────────────────┴──────────┴───────────────────┴────────┘
```

**Fix every row marked ✗ before proceeding.**

Common errors this catches:
- `scale()` used where `vs()` needed (or vice versa)
- `ms()` used for spacing instead of `scale()`
- Figma value forgotten (padding present in Figma but missing in code)
- Wrong color token mapped to hex
- `scale()` applied to letterSpacing or borderWidth
- Value "guessed" instead of taken from extraction map

### 4.2 — Structure check
Verify these without a table — quick pass:

- [ ] Every screen uses `useSafeAreaInsets()` (no hardcoded notch)
- [ ] Every shadow has `backgroundColor` on the same View
- [ ] Every font uses `Platform.select` or `typography.*` spread
- [ ] Zero hex colors in any StyleSheet (only `colors.*` tokens)
- [ ] Zero bare numbers in any StyleSheet (only `scale/vs/ms()` or exceptions list)
- [ ] `activeOpacity` on every TouchableOpacity
- [ ] `showsVerticalScrollIndicator={false}` on ScrollView/FlatList
- [ ] `keyExtractor` on every FlatList (not array index)
- [ ] `placeholderTextColor` on every TextInput

### 4.3 — Add DebugOverlay
```typescript
import { DebugOverlay } from '@/utils/DebugOverlay';

// At the end of screen JSX (inside the root View):
{__DEV__ && (
  <DebugOverlay source={require('@/assets/figma/HomeScreen.png')} />
)}
```
Tap the overlay to cycle opacity: 30% → 50% → 70% → hidden → 30%...

### 4.4 — Fix loop (NO re-fetching)
If any verification fails:
1. Find the exact Figma value from the extraction map (NOT from memory)
2. If the extraction map has `"INCOMPLETE"` — first try to infer from context (parent dimensions, sibling components, design patterns). Only re-call `get_design_context` as absolute last resort AND only if you're under the call budget.
3. Fix the code value
4. Re-run the verification table for that component
5. Repeat until all rows show ✓

**Do NOT re-fetch from Figma for minor discrepancies.** The extraction map is your source of truth. If a value is slightly ambiguous, use your best judgment from the surrounding context.

### 4.5 — Phase 4 summary (then proceed to Phase 5)
After code verification passes:
```
CODE AUDIT: {ScreenName}
- Components: 5 created (Header, Card, Button, Badge, ListItem)
- Files: 5 new, 2 updated (colors.ts, typography.ts)
- Tokens: 3 colors added, 1 typography style added
- Verification: 47/47 values match ✓
- Figma API calls: 2 used / 5 budget ✓
- Next: Phase 5 (simulator visual validation)
```
**Do NOT stop here.** If simulator MCP is available, proceed to Phase 5.

---

## PHASE 5 — VISUAL VALIDATION LOOP (iOS Simulator)

> **MANDATORY when iOS Simulator MCP is available.**
> This is the final gate. The screen is NOT done until this loop passes.
> Target: **99.9%+ visual match** with the Figma design.

### Prerequisites
- iOS Simulator is booted (`xcrun simctl boot "iPhone 16"`)
- App is running in the simulator (Expo / bare RN dev server)
- Figma screenshot is saved locally at `src/assets/figma/{ScreenName}_design.png` (from Step 1.4)
- Simulator MCP (`mobile-mcp` or `ios-simulator`) is connected

### 5.1 — Navigate to the screen
Use simulator MCP tools to navigate to the implemented screen:
```
mobile_launch_app(bundle_id)              ← launch the app
mobile_click_on_screen_at_coordinates(x, y)  ← tap to navigate if needed
mobile_swipe_on_screen(...)              ← scroll if needed
```

### 5.2 — Take simulator screenshot
```
mobile_take_screenshot() or screenshot(output_path)
```
Save to a TEMPORARY local path:
```
/tmp/{ScreenName}_simulator_{iteration}.png
```
**This costs ZERO Figma API calls** — it's a local simulator operation.

### 5.3 — Visual comparison (THE CORE LOOP)

**Read BOTH images and compare them side-by-side:**
1. Read the LOCAL Figma design file: `src/assets/figma/{ScreenName}_design.png`
2. Read the simulator screenshot: `/tmp/{ScreenName}_simulator_{iteration}.png`
3. Compare them visually, area by area, top to bottom:

**Comparison checklist — go through EVERY area:**

```
VISUAL COMPARISON: {ScreenName} — Iteration {N}
┌──────────────────────┬────────────┬─────────────────────────────────────┐
│ Area                 │ Match      │ Discrepancy                         │
├──────────────────────┼────────────┼─────────────────────────────────────┤
│ Status bar area      │ ✓ / ✗      │                                     │
│ Header / NavBar      │ ✓ / ✗      │ e.g., "title 2px too low"           │
│ Section 1            │ ✓ / ✗      │                                     │
│ Section 2            │ ✓ / ✗      │                                     │
│ Cards / List items   │ ✓ / ✗      │                                     │
│ Buttons / CTAs       │ ✓ / ✗      │                                     │
│ Colors match         │ ✓ / ✗      │ e.g., "bg slightly different"       │
│ Typography match     │ ✓ / ✗      │ e.g., "font size off by 1px"        │
│ Spacing / gaps       │ ✓ / ✗      │ e.g., "gap between cards too wide"  │
│ Border radius        │ ✓ / ✗      │                                     │
│ Shadows / elevation  │ ✓ / ✗      │                                     │
│ Bottom area / Footer │ ✓ / ✗      │                                     │
│ Overall alignment    │ ✓ / ✗      │                                     │
├──────────────────────┼────────────┼─────────────────────────────────────┤
│ TOTAL MATCH          │   ____%    │                                     │
└──────────────────────┴────────────┴─────────────────────────────────────┘
```

### 5.4 — Fix and repeat

**If match < 99.9%:**
1. List ALL discrepancies found in the comparison table
2. For each discrepancy:
   a. Identify the exact component and StyleSheet property causing it
   b. Look up the correct value from the extraction map (Phase 1 — LOCAL cache, no Figma calls)
   c. Fix the code
3. Wait for hot reload / rebuild
4. **Go back to Step 5.2** — take a NEW simulator screenshot and compare again

**Loop continues until ALL rows show ✓ and total match ≥ 99.9%.**

### 5.5 — Acceptable exceptions (do NOT count as failures)

These differences are expected and should NOT block the loop:
- Dynamic content (placeholder text vs real text — structure must match, content may differ)
- System UI differences (status bar time, battery, signal icons)
- Simulator-specific rendering (slight font antialiasing differences)
- Navigation chrome (if the screen uses native navigation headers)

### 5.6 — Max iterations safety valve

**Maximum 10 iterations.** If after 10 rounds the match is still < 99.9%:
1. Output the final comparison table with remaining discrepancies
2. Tell the user:
   > "Достигнут лимит итераций. Текущее совпадение: {N}%. Оставшиеся расхождения: {list}. Нужна ручная проверка."
3. List the specific CSS properties / components that still differ
4. Ask the user if they want to continue fixing or accept the current state

### 5.7 — Final result

After the loop passes (match ≥ 99.9%):
```
PIXEL-PERFECT VALIDATION: {ScreenName}
- Iterations: 3
- Final match: 99.9%+
- Figma reference: src/assets/figma/{ScreenName}_design.png (LOCAL)
- Final screenshot: /tmp/{ScreenName}_simulator_final.png
- Figma API calls used: 0 (all comparisons from local files)
- All areas: ✓
```

### 5.8 — Key principle: ZERO Figma API calls in Phase 5

The entire Phase 5 loop works with **only local files**:
- Figma design = local PNG saved in Step 1.4 (fetched ONCE)
- Simulator screenshot = taken locally via Simulator MCP (unlimited, free)
- Extraction map = cached JSON from Step 1.2 (in conversation context)

**No Figma API calls are made during the visual validation loop. Ever.**

---

## PHASE 6 — FINAL VERIFICATION GATE

> **MANDATORY. CANNOT BE SKIPPED. Task is NOT complete until this gate passes.**
> This is the last thing before delivering the result to the user.
> If ANY check fails → fix → re-run the ENTIRE gate. Loop until 100%.

### 6.1 — Requirements checklist (automated)

Run through EVERY check. Output as a table. **ALL must be ✓.**

```
FINAL GATE: {ScreenName}
═══════════════════════════════════════════════════════════════
REQUIREMENTS CHECK
┌────┬─────────────────────────────────────────────────┬────────┐
│ #  │ Requirement                                     │ Status │
├────┼─────────────────────────────────────────────────┼────────┤
│  1 │ useSafeAreaInsets() — no hardcoded notch        │ ✓ / ✗  │
│  2 │ Zero hex colors in StyleSheet (only colors.*)   │ ✓ / ✗  │
│  3 │ Zero bare numbers in StyleSheet (scale/vs/ms)   │ ✓ / ✗  │
│  4 │ Platform.select for fontFamily                  │ ✓ / ✗  │
│  5 │ getShadow() with backgroundColor on same View   │ ✓ / ✗  │
│  6 │ letterSpacing — direct value, no scale()        │ ✓ / ✗  │
│  7 │ borderWidth — direct value, no scale()          │ ✓ / ✗  │
│  8 │ activeOpacity on every TouchableOpacity         │ ✓ / ✗  │
│  9 │ keyExtractor on every FlatList (not index)      │ ✓ / ✗  │
│ 10 │ placeholderTextColor on every TextInput         │ ✓ / ✗  │
│ 11 │ showsVerticalScrollIndicator={false}            │ ✓ / ✗  │
│ 12 │ No Tailwind/NativeWind classes                  │ ✓ / ✗  │
│ 13 │ No inline styles with magic numbers             │ ✓ / ✗  │
│ 14 │ No import from icon packages (use Figma assets) │ ✓ / ✗  │
│ 15 │ Icons exported as SVG (or PNG@3x fallback)      │ ✓ / ✗  │
│ 16 │ All assets in src/assets/ (no Figma URLs)       │ ✓ / ✗  │
│ 17 │ Theme tokens used (colors, typography, spacing) │ ✓ / ✗  │
│ 18 │ scale() for horizontal, vs() for vertical       │ ✓ / ✗  │
│ 19 │ ms() only for fontSize/lineHeight/iconSize      │ ✓ / ✗  │
│ 20 │ TypeScript — no `any`, proper types              │ ✓ / ✗  │
├────┼─────────────────────────────────────────────────┼────────┤
│    │ TOTAL                                           │ __/20  │
└────┴─────────────────────────────────────────────────┴────────┘
```

**If any ✗ → fix the code → re-run this table. Do NOT proceed.**

### 6.2 — Value accuracy re-check

Re-read EVERY generated file. For each StyleSheet property, verify against the extraction map:

```
VALUE ACCURACY: {ScreenName}
┌──────────────────┬───────────────┬──────────┬────────┐
│ File             │ Total values  │ Matching │ Status │
├──────────────────┼───────────────┼──────────┼────────┤
│ HomeScreen.tsx   │ 34            │ 34       │ 100% ✓ │
│ HomeCard.tsx     │ 22            │ 22       │ 100% ✓ │
│ HomeHeader.tsx   │ 18            │ 18       │ 100% ✓ │
│ colors.ts        │ 8             │ 8        │ 100% ✓ │
│ typography.ts    │ 6             │ 6        │ 100% ✓ │
├──────────────────┼───────────────┼──────────┼────────┤
│ TOTAL            │ 88            │ 88       │ 100% ✓ │
└──────────────────┴───────────────┴──────────┴────────┘
```

**If any file < 100% → list the mismatched values → fix → re-check.**

### 6.3 — Visual match confirmation

**If simulator MCP is available:**
1. Take a FINAL screenshot of the implemented screen
2. Compare side-by-side with Figma design (local PNG)
3. The result MUST be ≥ 99.9% match from Phase 5
4. If Phase 5 was not run yet → run it NOW before proceeding

**If simulator MCP is NOT available:**
1. Re-read the Figma screenshot (local PNG from Step 1.4)
2. Re-read all component code
3. Mentally verify every area matches the design
4. List any areas of uncertainty

### 6.4 — Figma re-fetch verification (final truth check)

> This is the ONE place where re-fetching from Figma is allowed.

1. Call `get_design_context` ONE more time for the root node
2. Compare the FRESH data against your extraction map — verify nothing was misread in Phase 1
3. Check 5 random values from the fresh response against the generated code
4. If any mismatch found → fix → re-run 6.2

**Skip this step ONLY if:**
- Figma MCP is disconnected and cannot be recovered
- You already used get_design_context in the last 5 minutes (data is fresh)

### 6.5 — Gate verdict

**ALL of these must be true to pass:**
- [ ] 6.1 Requirements: 20/20 ✓
- [ ] 6.2 Value accuracy: 100% across all files
- [ ] 6.3 Visual match: ≥ 99.9% (or manual confirmation if no simulator)
- [ ] 6.4 Figma re-fetch: no mismatches (or skipped with reason)

```
FINAL VERDICT: {ScreenName}
═══════════════════════════════════════════════════
│ Requirements:     20/20 ✓                       │
│ Value accuracy:   88/88 (100%) ✓                │
│ Visual match:     99.9%+ ✓                      │
│ Figma re-fetch:   5/5 values confirmed ✓        │
│                                                 │
│ ██████████████████████████████████████ PASSED ✓  │
═══════════════════════════════════════════════════
```

### 6.6 — Gate FAILED → fix loop

**If the gate fails at ANY step:**
1. List ALL failures with exact file:line and what's wrong
2. Fix every issue
3. **Re-run the ENTIRE Phase 6 from 6.1** — not just the failed step
4. Repeat until PASSED

**There is NO maximum iteration limit for Phase 6.** The task is not delivered until the gate passes.

### 6.7 — Deliver to user

ONLY after the gate passes:
1. Output the final PASSED verdict table
2. List all created/modified files
3. Tell the user: "Готово. Все проверки пройдены."
4. **Do NOT stop early. Do NOT say "looks good" without running the gate.**

---

## ANTI-PATTERNS — NEVER DO

```typescript
// ❌ Tailwind / NativeWind
<View className="px-4 py-6 rounded-xl bg-blue-500" />

// ❌ Inline styles with magic numbers
<View style={{ padding: 16, backgroundColor: '#3B82F6' }} />

// ❌ Hardcoded numbers (no scale)
paddingHorizontal: 16

// ❌ Hardcoded colors (no theme)
backgroundColor: '#F9FAFB'

// ❌ Hardcoded notch offset
paddingTop: 44

// ❌ Missing Platform.select for fonts
fontFamily: 'Roboto'  // will not work on iOS

// ❌ Missing Platform for shadows
shadowColor: '#000'   // invisible on Android without elevation

// ❌ Icon packages when Figma provides assets
import { HomeIcon } from 'lucide-react-native'  // Figma already has the icon

// ❌ scale() for letterSpacing
letterSpacing: scale(-0.3)  // distorts tracking

// ❌ scale() for borderWidth
borderWidth: scale(1)  // fractional border = visual artifacts

// ❌ ms() for spacing
paddingHorizontal: ms(16)  // ms is for fonts, use scale()
```

---

## WHEN FIGMA MCP RETURNS TAILWIND/JSX

The MCP may return React + Tailwind by default. **IGNORE all Tailwind classes completely.**
Use ONLY the raw px values from the design context and convert them via the table in 3.2.

---

## FILE PLACEMENT

```
src/
  screens/
    {Name}Screen.tsx          ← screen container (SafeArea, ScrollView/FlatList, data wiring)
  components/
    ui/                       ← reusable atoms (Button, Input, Badge, Avatar, Chip)
      Button.tsx
      Input.tsx
      Badge.tsx
    {feature}/                ← feature-specific composites
      {Feature}Card.tsx
      {Feature}Header.tsx
      {Feature}List.tsx
  theme/
    colors.ts                 ← synced from Figma Variables
    typography.ts             ← synced from Figma Text Styles
    spacing.ts                ← horizontal + vertical spacing tokens
    radius.ts                 ← border radius tokens
    shadows.ts                ← cross-platform shadow utility
    index.ts                  ← barrel: export { colors, typography, spacing, ... }
  utils/
    scale.ts                  ← scale(), vs(), ms()
    DebugOverlay.tsx           ← dev-only Figma screenshot overlay
  assets/
    figma/                    ← Figma screenshots for DebugOverlay
      {Name}Screen.png
    icons/                    ← downloaded Figma icons for production
    images/                   ← downloaded Figma images for production
```

---

## INVOCATION EXAMPLES

**User pastes a Figma link:**
> "Верстай HomeScreen по https://figma.com/design/abc/App?node-id=1-2"

→ Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → **Phase 6 (final gate)**

**User wants a single component:**
> "Добавь компонент карточки из Figma https://..."

→ Phase 0 → Phase 1 → Phase 3.5 → Phase 4.2 → **Phase 6 (final gate)**

**User wants to sync theme only:**
> "Обнови тему из Figma Variables https://..."

→ Phase 1.5 → Phase 2 → done (no Phase 6 — theme-only sync)

**User wants validation only:**
> "Проверь совпадение с дизайном"

→ Phase 5 → **Phase 6 (final gate)**

**User selects in Figma:**
> "Верстай выделенное"

→ get_selection → Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → **Phase 6**

**User provides Figma link without instructions:**
> "https://figma.com/design/abc/App?node-id=1-2"

→ Full cycle: Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → **Phase 6 (final gate)**

> **Phase 6 is MANDATORY for any task that produces code.** Task is NEVER delivered without passing the final gate.
