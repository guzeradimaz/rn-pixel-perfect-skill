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
Integrates with Figma MCP (`figma-mcp-go`). Reads design values directly from Figma.
Outputs pure `StyleSheet.create({})` with `scale()`, `vs()`, `ms()`, theme tokens.
**NO Tailwind. NO NativeWind. NO hardcoded values.**

### Reference files (read when needed)
- `references/scale-guide.md` — scale()/vs()/ms() rules, vs() scope, lineHeight from Figma
- `references/platform-patterns.md` — shadows, fonts, SafeArea, FlatList, Modal, animations, acceptable diffs
- `references/pixel-diff.md` — pixel comparison script instructions (Phase 5)
- `references/pixel-diff.py` — runnable pixel diff script (Phase 5)

Search for these in `{projectRoot}/.claude/skills/rn-pixel-perfect/references/` or `~/.claude/skills/rn-pixel-perfect/references/`.

---

## QUICK REFERENCE

```
scale(n)   → horizontal: width, paddingH, marginH, borderRadius, gap
vs(n)      → vertical: height, paddingV, marginV, top, bottom
ms(n)      → fonts and icons only (moderate scale, factor 0.5)
colors.*   → ALL colors from src/theme/colors.ts
typography → font presets from src/theme/typography.ts
spacing.*  → horizontal spacing tokens
vSpacing.* → vertical spacing tokens
radius.*   → border radii tokens
getShadow(token)    → preset shadow from src/theme/shadows.ts (tokens updated from Figma in Phase 2)
createShadow({...}) → exact shadow from Figma values: blur, offsetY, offsetX, opacity, color
```

**NEVER:** hardcode px · Tailwind/NativeWind · className · inline styles · hex colors ·
omit useSafeAreaInsets · scale(letterSpacing) · scale(borderWidth) · scale(opacity) ·
emoji as icon/image placeholders · CSS hacks for arrows/chevrons

---

## CORE PRINCIPLES

1. **Export real assets** — PNG/SVG from Figma via `save_screenshots`. NEVER emoji (💎⚡📚) as icons. NEVER CSS border+rotate for arrows.
2. **Plan before code** — Phase 3.1 is mandatory. List components, assets, decisions. Do NOT skip.
3. **Think out loud** — before every non-trivial decision, write a paragraph: what options exist, why you chose this, what trade-offs.
4. **Programmatic first, PNG last resort** — DEFAULT is ALWAYS programmatic. PNG only when RN literally cannot render it: blend modes (Multiply/Screen/Overlay), radial gradients, raster illustrations. Linear gradients → always `LinearGradient`. Absolute layouts → `position: 'absolute'`. Icon+badge → `View` overlay. NEVER convert standard UI to PNG just because it has >3 elements.
5. **Decompose & reuse** — extract shared atoms (Badge, IconButton, PlayButton) BEFORE feature components. Never duplicate a pattern.
6. **Install libraries yourself** — run `npm install` + `pod install` directly. Don't just inform the user.
7. **Verify ruthlessly** — Phase 4 & 6 are mandatory gates. If verification fails → fix → re-verify.
8. **`save_screenshots` paths MUST be relative** — `src/assets/icons/foo.png` ✅ · `/Users/name/project/src/...` ❌ WILL FAIL.

---

## FIGMA MCP SERVER: figma-mcp-go

> Uses `@vkhanhqui/figma-mcp-go` — reads via **Figma Desktop plugin bridge**, NOT REST API.
> **No API key. No rate limits.**

### Prerequisites
1. **Figma Desktop** must be running (not web)
2. **figma-mcp-go plugin** active in the open file: Plugins → Development → Import plugin from manifest → run it
3. MCP server configured in `~/.claude/settings.json`

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

### Call strategy

No rate limits, but extract maximum data per call to stay efficient.

1. **ONE `get_design_context` call for root node FIRST.** Extract everything. Write extraction map immediately.
2. **Fetch child nodes freely if data is incomplete.** Only if values are truly missing.
3. **`get_screenshot`** — call for root node for Phase 5. Save locally once, reuse forever.
4. **`get_variable_defs`** — only if colors reference variable names instead of hex.
5. **`get_selection`** for "верстай выделенное" — WARNING: often returns 100K-300K+ chars.
   - Response is saved to a temp file. NEVER read the entire file at once.
   - Use Python via Bash to parse in passes:
     ```python
     # Pass 1: tree structure (names, types, bounds, IDs)
     # Pass 2: text content (scan_text_nodes is often easier)
     # Pass 3: specific styles (fills, fonts, radii)
     ```
   - Also call `scan_text_nodes(nodeId)` separately for compact text data.
6. **NEVER re-fetch data you already have.** Extraction map is your cache.

### Call sequence

```
CALL 1: get_design_context(fileKey, rootNodeId, dedupe_components: true)
        → dedupe_components cuts response size 2-5x on screens with repeated components
        → Extract EVERYTHING: layout, colors, fonts, spacing, children
        → Fill the complete extraction map

CALL 2 (if needed): get_design_context(fileKey, childNodeId)
        → For sections truncated/missing in Call 1
        → Merge into extraction map

CALL 3: get_screenshot(fileKey, rootNodeId) → save locally for Phase 5

CALL 4 (if needed): get_variable_defs(fileKey) → for theme token sync
```

**Handling large MCP responses (100K-300K chars):**
1. Response is saved to a temp file — read the file path from tool output
2. Parse with Python/jq via Bash in passes (structure → text → styles)
3. Use `dedupe_components: true` first — biggest single reduction
4. Use `detail: "compact"` for first pass, then `detail: "full"` for specific subtrees

---

## PHASE 0 — PROJECT SCAFFOLDING

### Step 0.0 — Check Figma MCP availability

Call `get_metadata()` (no required params, safe test call).

**Case A — tool not found (MCP not configured):**
Tell user:
> "Figma MCP не подключён. Нужен `figma-mcp-go`."

Recommended setup (with auto-restart proxy):
```json
"mcpServers": {
  "figma-mcp-go": {
    "command": "node",
    "args": ["~/.claude/scripts/figma-mcp-proxy.js"]
  }
}
```
Install proxy: `cp scripts/figma-mcp-proxy.js ~/.claude/scripts/`

Direct setup (no proxy):
```json
"figma-mcp-go": {
  "command": "npx",
  "args": ["-y", "@vkhanhqui/figma-mcp-go"]
}
```
Then: Figma Desktop → Plugins → Development → Import plugin from manifest → run in the file → restart Claude Code.

**Case B — tool responds but returns empty / "plugin not connected":**
Tell user: "Открой Figma Desktop и запусти плагин figma-mcp-go в нужном файле."

**Case C — tool returns valid data:** proceed to 0.0.1.

### Step 0.0.1 — Check simulator MCP availability

To detect which simulator MCP is available, try these tools in order:
1. Try `mobile_take_screenshot()` → if succeeds, set `simulatorMCP = "mobile-mcp"`
2. Try `screenshot(output_path: "/tmp/mcp_test.png")` → if succeeds, set `simulatorMCP = "ios-simulator"`
3. If both fail → `simulatorMCP = null` → Phase 5 will be manual

Tell user if not available:
> "Simulator MCP не найден. Phase 5 (визуальная проверка) будет пропущена. Для установки: `npx -y @mobilenext/mobile-mcp@latest`"

**Phase 5 is MANDATORY when simulatorMCP is not null.**

### Step 0.0.2 — MCP Resilience

| Error type | Symptoms | Action |
|-----------|----------|--------|
| Server crash | "disconnected", timeout, "tool not available" after working | Retry once after 3s. If fails: use cached extraction map, continue. |
| Plugin disconnected | MCP responds but empty data | Tell user to restart plugin in Figma Desktop |
| Not configured | "tool not found" on first call | Step 0.0 |

On crash: continue with cached extraction map. Phase 5 works without Figma MCP (all local files).

### Step 0.1 — Detect existing structure

Check which files exist:
```
src/utils/scale.ts
src/utils/DebugOverlay.tsx
src/theme/colors.ts
src/theme/typography.ts
src/theme/spacing.ts
src/theme/radius.ts
src/theme/shadows.ts
src/theme/index.ts
```

### Step 0.2 — Create missing files from templates

For every missing file, copy from `references/templates/` (skill directory).
Adapt imports to match the project's path alias (`@/`, `~/`, `../` — check `tsconfig.json → paths`).

### Step 0.3 — Install base dependencies

Check `package.json` and **install missing deps automatically — don't just inform the user:**

| Library | Required | Bare RN | Expo |
|---------|----------|---------|------|
| `react-native-safe-area-context` | **ALWAYS** | same | same |
| `react-native-svg` | **ALWAYS** | same | same |
| `react-native-linear-gradient` | **ALWAYS** | same | `expo-linear-gradient` |
| `@react-native-community/blur` | Only if design has blur | same | `expo-blur` |

```bash
# Bare RN:
npm install react-native-safe-area-context react-native-svg react-native-linear-gradient
cd ios && pod install && cd ..

# Expo:
npx expo install react-native-safe-area-context react-native-svg expo-linear-gradient
```

**App MUST be rebuilt after installing native modules** (hot reload is not enough).

#### SVG transformer (required to use .svg files in RN):

After installing `react-native-svg`, configure the metro transformer once:

```bash
npm install --save-dev react-native-svg-transformer
```

`metro.config.js`:
```javascript
const { getDefaultConfig } = require('metro-config');
module.exports = (async () => {
  const { resolver: { sourceExts, assetExts } } = await getDefaultConfig();
  return {
    transformer: { babelTransformerPath: require.resolve('react-native-svg-transformer') },
    resolver: {
      assetExts: assetExts.filter(ext => ext !== 'svg'),
      sourceExts: [...sourceExts, 'svg'],
    },
  };
})();
```

`declarations.d.ts` (or `@types`):
```typescript
declare module '*.svg' {
  import React from 'react';
  import { SvgProps } from 'react-native-svg';
  const content: React.FC<SvgProps>;
  export default content;
}
```

Check if `metro.config.js` already has SVG transformer — if yes, skip. Rebuild required after this change.

### Step 0.3.1 — Research unfamiliar patterns

If the design uses ANY feature you haven't implemented before:
1. Search the web for implementation examples
2. Read official docs/README
3. Check React Native version compatibility
4. Install + rebuild before writing code
5. Document your reasoning (why this library, what alternatives exist)

### Step 0.4 — Detect custom fonts

After Phase 1, check `fontFamily` values in the extraction map.
If custom font (not system SF Pro / Roboto):

1. Check for `.ttf`/`.otf` in `src/assets/fonts/` or `assets/fonts/`
2. If missing — tell user the font name and install steps:
   - **Bare RN:** `react-native.config.js` → `assets: ['./src/assets/fonts/']` → `npx react-native-asset` → rebuild
   - **Expo:** `assets/fonts/` + `expo-font` plugin in `app.json`
3. Use font name in code immediately (system fallback renders until font is added)

### Step 0.5 — Detect BASE_WIDTH

If `scale.ts` exists, read current `BASE_WIDTH`. Update in Phase 1 if Figma frame differs.

| Width | Device |
|-------|--------|
| 390 | iPhone 14/15 (most common, template default) |
| 393 | iPhone 14 Pro / 15 Pro / 16 (**easy to confuse with 390**) |
| 375 | iPhone SE / older |
| 430 | iPhone Pro Max |
| 360 | Android standard |

**CRITICAL:** 390 vs 393 mismatch = ~0.8% scaling error across the entire screen. Always verify from `get_design_context` and update `BASE_WIDTH` immediately.

---

## PHASE 1 — FIGMA RECONNAISSANCE

### Step 1.1 — Parse URL

```
https://figma.com/design/{fileKey}/Name?node-id={nodeId}
https://www.figma.com/file/{fileKey}/Name?node-id={nodeId}
```
Node IDs in URLs use `-` (e.g., `1-2`). MCP may need `:` format (e.g., `1:2`). Try both if one fails.

### Step 1.2 — Get design context

```
get_design_context(fileKey, nodeId, dedupe_components: true)
```

**This is your most important call. Extract EVERYTHING into the extraction map immediately.**

#### Parameters:
| Parameter | When to use |
|-----------|------------|
| `dedupe_components: true` | **ALWAYS** — cuts response 2-5x |
| `depth: 3` | Default first call |
| `depth: 5+` | Only if sections are truncated |
| `detail: "compact"` | First pass on complex screens |
| `detail: "full"` | Second call for specific sections |

> ⚠️ **dedupe_components drops variant states.** After the main call, re-fetch all interactive components
> (TabBar, Button, Toggle, Checkbox, Selector, any component with active/pressed/disabled states):
> ```
> get_design_context(fileKey, componentNodeId, dedupe_components: false)
> ```
> This is the only way to get active/inactive colors, pressed styles, and disabled states correctly.

The MCP may return React + Tailwind code — **IGNORE Tailwind classes entirely**, use only raw px values.

**Write the COMPLETE extraction map immediately after the response:**

```json
{
  "screen": "HomeScreen",
  "frame": { "width": 390, "height": 844 },
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
      "colors": { "background": "#FFFFFF", "text": "#000000" },
      "radius": 0,
      "shadow": {
        "blur": 20, "offsetX": 0, "offsetY": 8,
        "opacity": 0.08, "color": "#1B1F2A"
      },
      "gradient": null,
      "children": ["BackButton", "Title", "ActionButton"]
    }
  ]
}
```

**Rules:**
- Record EVERY px value exactly as Figma shows — do not round or guess
- Ambiguous value → infer from context (parent padding, siblings) — do NOT re-call MCP
- Truly missing critical values → mark `"INCOMPLETE"` — these are the ONLY reason for another call
- Frame width ≠ current `BASE_WIDTH` → update `scale.ts` BEFORE coding
- **`visible: false` → SKIP entirely.** Do not add to extraction map, do not render. Hidden layers in Figma = do not exist in code.
- **`opacity: 0` → SKIP.** Invisible layer, same rule. Exception: if opacity is animated (check layer name for "skeleton", "loading", "placeholder" hints — then render with `opacity: 0` as initial state).

**Shadow extraction** — from `effects[]` array in the node:
```
type: "DROP_SHADOW" → extract: blur, offset.x, offset.y, color {r,g,b,a}, opacity
color: r/g/b values are 0–1 floats → convert to hex: #RRGGBB
opacity: use color.a OR effect.opacity (whichever is present)
```
Record in extraction map as: `"shadow": { "blur": 20, "offsetY": 8, "offsetX": 0, "opacity": 0.08, "color": "#1B1F2A" }`

**Gradient extraction** — from `fills[]` array when `type: "GRADIENT_LINEAR"`:
```
gradientStops[].color → convert r/g/b (0–1) to hex
gradientStops[].position → use directly (0–1)
gradientHandlePositions[0] → start {x, y}
gradientHandlePositions[1] → end {x, y}
```
Record as: `"gradient": { "type": "linear", "colors": ["#3870E0","#1CAAFE"], "locations": [0,1], "start": {"x":0,"y":0.5}, "end": {"x":1,"y":0.5} }`

#### Handling duplicate sections:
If two sections share the same component name — extract from ONE instance only.
Different text/colors = different states (active vs inactive). When in doubt, ask the user.

### Step 1.2.1 — Spot-check extraction map (MANDATORY)

After writing the extraction map, verify 3 random values to catch `get_design_context` approximation errors:

1. Pick 3 values: one padding/margin, one color, one fontSize
2. Call `get_node(nodeId)` for the node that owns each value
3. Compare raw response with what's in the extraction map

**If difference > 1px or color differs → re-read that section via `get_design_context(childNodeId)`.**

This catches cases where MCP returned rounded/truncated values in the main context call.

### Step 1.3 — Assess completeness

- Has `"INCOMPLETE"` values that BLOCK implementation? → ONE more `get_design_context` call for missing section, merge into map.
- All data present? → proceed to Phase 2. Do NOT make extra calls "just to be sure".

### Step 1.4 — Get screenshot and save locally

```
get_screenshot(nodeIds: ["1:23"], format: "PNG", scale: 1)
```
Call when simulator MCP is available or user asks for visual validation.

> **scale: 1** — симулятор отдаёт logical pixels; Figma @2x = физические пиксели другого масштаба.
> При сравнении pixel-diff скрипт ресайзит под одинаковый размер, но одинаковый масштаб сохранения даёт точнее.

**Save IMMEDIATELY to permanent location:**
```
src/assets/figma/{ScreenName}_design.png
```
**One screenshot per screen. Save once, reuse forever. All Phase 5 comparisons use this local file.**

### Step 1.4.1 — Export icons and images

#### Batch detection first:
```
scan_nodes_by_types(nodeId: "{rootNodeId}", types: ["VECTOR", "BOOLEAN_OPERATION", "INSTANCE"])
```
Filter by name patterns (`"icon-"`, `"Interface"`, `"Arrow"`) to build export list before manual searching.

#### Format rules:
| Asset type | Format | Scale |
|-----------|--------|-------|
| Icons (monochrome) | SVG | — |
| Icons (SVG fails) | PNG | 3 |
| Illustrations | SVG | — |
| Photos / raster | PNG | 2 |
| Screen reference (Phase 5) | PNG | 2 |

#### Batch export:
```
save_screenshots(items: [
  { nodeId: "1:23", outputPath: "src/assets/icons/home.svg", format: "SVG" },
  { nodeId: "1:24", outputPath: "src/assets/icons/search.png", format: "PNG", scale: 3 },
  { nodeId: "1:30", outputPath: "src/assets/images/hero.png", format: "PNG", scale: 2 }
])
```

> **`outputPath` MUST be relative to project root.**
> ✅ `"src/assets/icons/home.svg"` · ❌ `"/Users/name/project/src/..."` — WILL FAIL

#### The white-on-transparent problem (very common)

Many Figma icons are white vectors on transparent background. Detection:
- SVG: `"Failed to export node. This node may not have any visible layers."`
- PNG: file created but ≤ 200 bytes (empty/transparent)

**Fallback chain:**
```
ATTEMPT 1: Export icon as SVG
           → Success? Done.
           → "No visible layers"? → ATTEMPT 2

ATTEMPT 2: Export icon as PNG @3x
           → file > 200 bytes? Done.
           → file ≤ 200 bytes? → ATTEMPT 3

ATTEMPT 3: Export PARENT FRAME (icon + its background)
           → Usually works. Use as composite.

ATTEMPT 4: Export COMPOSITE SECTION as single image
           → e.g., entire tab bar, entire header, entire card
```

After all exports, clean up empty files:
```bash
find src/assets -type f \( -name "*.png" -o -name "*.svg" \) -size -200c -delete
```

**Using `tintColor` for monochrome icons with dynamic color:**
```typescript
<Image
  source={require('@/assets/icons/bell.png')}
  style={{ width: ms(24), height: ms(24), tintColor: colors.text.primary }}
  resizeMode="contain"
/>
```

#### Key rules:
1. Try SVG first, expect failures on white-on-transparent → follow fallback chain
2. Validate EVERY export: PNG > 200 bytes = success
3. NEVER emoji as icon placeholders. If all attempts fail → colored `View` + `// TODO: export icon`
4. Never use Figma image URLs in production — always `require()`
5. `RECTANGLE` nodes with image fills → always export PNG @2x
6. Simple geometric icons (arrows, chevrons, plus, close) → always export from Figma. NEVER build with CSS border+rotate hacks.
7. File naming: `icon-home.svg`, `img-hero.png` (lowercase kebab-case)

**Save to:**
```
src/assets/icons/    ← SVG and PNG icons
src/assets/images/   ← photos, illustrations, composite exports
src/assets/figma/    ← design reference screenshots (Phase 5 only)
```

### Step 1.4.2 — Validate exports (mandatory after every batch)

```bash
# Find blank PNGs (≤200 bytes = failed export)
find src/assets -name "*.png" -size -200c -exec ls -la {} \;
```

If ANY file ≤ 200 bytes → follow fallback chain immediately. Do NOT proceed to Phase 3 with blank assets.

### Step 1.5 — Get design tokens (only if needed)

```
get_variable_defs(fileKey)
```
Call ONLY if: user explicitly asks for Figma Variables sync, OR colors reference variable names instead of hex.

### Step 1.6 — Design-driven library scan (MANDATORY after extraction map)

Scan extraction map for non-standard UI patterns. For each detected pattern:
1. Check if library already in `package.json`
2. If not — web search: `"react native [pattern] library 2024 best"`
3. Pick most maintained (GitHub stars, last commit, RN version support)
4. Install immediately + pod install if native
5. Document decision: why this library, what alternatives exist

**Pattern detection table:**

| Pattern in design | Triggers research | Popular options |
|-------------------|-------------------|-----------------|
| Animations (any non-trivial) | `react-native-reanimated` | already in Expo; for bare RN install + rebuild |
| Bottom sheet / drawer | `@gorhom/bottom-sheet` | vs `react-native-bottom-sheet` |
| Horizontal carousel / snap scroll | usually built-in FlatList | vs `react-native-snap-carousel` |
| Charts / graphs | `victory-native` | vs `react-native-gifted-charts` vs `recharts` |
| Map / location | `react-native-maps` | no real alternative |
| Video player | `react-native-video` | vs `expo-video` |
| Date / time picker | `@react-native-community/datetimepicker` | vs `react-native-date-picker` |
| Swipeable list items | `react-native-gesture-handler` (often pre-installed) | — |
| Skeleton / shimmer loading | `react-native-skeleton-placeholder` | vs custom Reanimated |
| Blur overlay | `@react-native-community/blur` | vs `expo-blur` |
| Lottie animation | `lottie-react-native` | — |
| Onboarding / swiper screens | `react-native-onboarding-swiper` | vs FlatList paginator |
| Progress bar / circular progress | `react-native-progress` | vs custom Reanimated |
| Masked input | `react-native-mask-input` | — |
| Rich text / markdown | `react-native-markdown-display` | — |

**Decision rule:**
- If a pattern can be cleanly built with standard RN primitives + Reanimated in ≤50 lines → build it
- If it requires >50 lines or significant gesture handling → use a library
- Always prefer libraries that are: TypeScript-native, Expo-compatible, actively maintained

**After detecting and installing all libraries → rebuild the app before Phase 3.**

---

## PHASE 2 — TOKEN SYNC

Update theme files with values from extraction map. Only update values that differ from Figma.

### Colors → src/theme/colors.ts
```typescript
export const colors = {
  primary: { default: '#...', pressed: '#...', disabled: '#...' },
  background: { primary: '#...', secondary: '#...', tertiary: '#...' },
  text: { primary: '#...', secondary: '#...', placeholder: '#...', inverse: '#...', disabled: '#...' },
  border: { default: '#...', focused: '#...' },
  status: { success: '#...', error: '#...', warning: '#...', info: '#...' },
} as const;
```

**Dark mode support:**
```typescript
export const lightColors = { /* ... */ } as const;
export const darkColors = { /* ... */ } as const;
export type Colors = typeof lightColors;
export const colors = lightColors;
```

### Typography → src/theme/typography.ts
```typescript
import { Platform } from 'react-native';
import { ms } from '@/utils/scale';

export const typography = {
  h1: {
    fontSize: ms(32), lineHeight: ms(40), fontWeight: '700' as const,
    fontFamily: Platform.select({ ios: 'SF Pro Display', android: 'Roboto-Bold' }),
  },
  body1: {
    fontSize: ms(16), lineHeight: ms(24), fontWeight: '400' as const,
    fontFamily: Platform.select({ ios: 'SF Pro Text', android: 'Roboto' }),
  },
};
```

### Spacing → src/theme/spacing.ts
Map Figma spacing values to semantic tokens using `scale()` and `vs()`.

### Radius → src/theme/radius.ts
Map Figma corner radius values to semantic tokens using `scale()`.

### Shadows → src/theme/shadows.ts

Extract exact shadow values from Figma. **Do NOT map to nearest preset — use actual values.**

For each shadow in the design:
```
get_design_context response → effects[] → type: "DROP_SHADOW" → extract:
  blur     → figmaBlur
  offset.x → offsetX
  offset.y → offsetY
  color    → convert { r, g, b } (0–1 floats) to hex: #RRGGBB
  opacity  → from color.a OR effect's opacity field
```

**Figma → iOS conversion:**
```
shadowRadius = figmaBlur / 2
```
Figma blur = Gaussian standard deviation × 2. iOS shadowRadius = std deviation. This is the only non-obvious conversion.

**Update shadowTokens in shadows.ts with real Figma values:**
```typescript
export const shadowTokens = {
  card: createShadow({ blur: 20, offsetY: 8, opacity: 0.08, color: '#1B1F2A' }),
  button: createShadow({ blur: 8,  offsetY: 4, opacity: 0.12 }),
  modal: createShadow({ blur: 40, offsetY: 16, opacity: 0.15, color: '#000' }),
};
```

Name tokens semantically (card, button, modal, tooltip) — NOT by size (sm/md/lg).

**Multiple shadows:** Figma layers `effects` array can have multiple DROP_SHADOWs.
RN doesn't support multiple shadows natively — use the most visually dominant one.
For truly important stacked shadows → export the element as PNG Image.

---

## PHASE 3 — IMPLEMENTATION

### 3.0 — Image vs Programmatic decision (BEFORE coding)

**DEFAULT IS ALWAYS PROGRAMMATIC.** Only export as PNG when RN literally cannot render the effect.

#### Always PROGRAMMATIC — do NOT use PNG for these:

| Pattern | How to implement |
|---------|-----------------|
| Linear gradient | `LinearGradient` from expo-linear-gradient |
| Gradient button / card | `LinearGradient` as container |
| Gradient overlay (text readability) | `LinearGradient` with `StyleSheet.absoluteFillObject` |
| Absolute positioned elements | `position: 'absolute'`, `top/left/right/bottom` |
| Hero section with background | `View` + `LinearGradient` or `ImageBackground` |
| Icon + badge composition | `View` with `position: 'absolute'` badge overlay |
| Cards with shadows | `View` + `createShadow()` |
| Multiple overlapping Views | Use `zIndex` or natural stacking order |
| Static branding with text | `View` + `Text` + `LinearGradient` if needed |
| Tab bar / navigation | Always programmatic — states need to change |
| Buttons, inputs, modals | Always programmatic |
| List items, cards, sections | Always programmatic |

#### Export as PNG — LAST RESORT, only when ALL conditions are true:

1. **Purely decorative** — zero text, zero interaction, zero dynamic content
2. **AND** contains RN-incompatible effects:
   - Blend modes: Multiply / Screen / Overlay / Hard Light
   - Radial gradient with complex clipping or shapes
   - Detailed raster illustration (characters, scenes)
   - 5+ stacked shadows that are visually critical
3. **AND** the element will NEVER change based on state or data

**Before deciding PNG — ask yourself:**
- Does this element have text inside? → PROGRAMMATIC
- Does this element ever change color/content? → PROGRAMMATIC
- Is this a gradient? → LinearGradient (NEVER PNG for linear gradients)
- Is this multiple Views overlapping? → position:absolute (NEVER PNG)
- Could I build this in <100 lines without hacks? → PROGRAMMATIC

**Composite image + touchable overlay (for interactive complex visuals):**
```typescript
import { View, Image, TouchableOpacity } from 'react-native';
import { useState, useCallback } from 'react';
import { scale, vs } from '@/utils/scale';

// Positions as % of image size, derived from Figma coordinates
const AREAS = [
  { id: 'lifestyle', xPct: 0.48, yPct: 0.32, widthPct: 0.18, heightPct: 0.12 },
] as const;

export const WheelSection: React.FC<{ onPress: (id: string) => void }> = ({ onPress }) => {
  const [size, setSize] = useState({ width: 0, height: 0 });

  const handleLayout = useCallback((e: LayoutChangeEvent) => {
    const { width, height } = e.nativeEvent.layout;
    setSize({ width, height });
  }, []);

  return (
    <View onLayout={handleLayout}>
      <Image
        source={require('@/assets/images/wheel.png')}
        style={{ width: scale(321), height: vs(321) }}
        resizeMode="contain"
      />
      {size.width > 0 && AREAS.map(area => (
        <TouchableOpacity
          key={area.id}
          activeOpacity={0.6}
          style={{
            position: 'absolute',
            left: area.xPct * size.width - (area.widthPct * size.width) / 2,
            top: area.yPct * size.height - (area.heightPct * size.height) / 2,
            width: area.widthPct * size.width,
            height: area.heightPct * size.height,
          }}
          onPress={() => onPress(area.id)}
        />
      ))}
    </View>
  );
};
```

### 3.1 — Implementation plan (MANDATORY before any code)

> **DO NOT WRITE ANY COMPONENT CODE UNTIL THIS PLAN IS COMPLETE.**

Output this plan in your response:
```
IMPLEMENTATION PLAN: HomeScreen
═══════════════════════════════

THOUGHT PROCESS:
- Header has 4 circular icon buttons → extract IconButton atom
- Play button appears in FavoriteCard AND LessonCard → extract PlayButton atom
- "5 min" badge appears in 3 places → extract Badge atom
- Wheel section: overlapping gradients + pattern → EXPORT AS PNG (too complex for Views)

ATOMS (create first):
  src/components/ui/IconButton.tsx
  src/components/ui/PlayButton.tsx
  src/components/ui/Badge.tsx

COMPOSITES:
  src/components/home/HomeHeader.tsx
  src/components/home/FavoriteSection.tsx
  src/components/home/LessonsSection.tsx
  src/components/home/HomeTabBar.tsx
  src/components/home/AreasOfLifeWheel.tsx

SCREEN:
  src/screens/HomeScreen.tsx

ASSETS TO EXPORT (13 total):
  Icons @3x: tab-search, tab-book, tab-home, tab-save, tab-dna
  Icons @3x: header-bell, header-chat, header-coin
  Icons @3x: arrow-down
  Images @2x: lesson-1, lesson-2
  Composite @3x: wheel-bg
  Reference @2x: HomeScreen_design

IMAGE VS PROGRAMMATIC:
  Header → PROGRAMMATIC (simple flex, interactive)
  Wheel → IMAGE (complex overlapping gradient + pattern)
  Cards → PROGRAMMATIC (dynamic text + images)
  TabBar → PROGRAMMATIC (active state changes)

DEPENDENCIES: react-native-linear-gradient ✓, react-native-svg ✓
```

### 3.2 — Extract shared atoms FIRST

Scan extraction map for patterns appearing 2+ times. Extract to `src/components/ui/` before feature components.

**Rule: NEVER implement the same visual pattern twice.**

### 3.3 — Component breakdown

```
Screen (SafeArea + ScrollView/FlatList + data wiring)
  ├── Header / NavigationBar
  ├── Content sections
  │   ├── Section cards / items
  │   └── ...
  ├── UI atoms: Button, Input, Badge, Avatar...
  └── Footer / TabBar
```

Shared UI atoms → `src/components/ui/`
Feature components → `src/components/{feature}/`

### 3.3.1 — Implementation order

**Bottom-up: atoms → composites → screen.**

For each component:
1. Look up exact values from extraction map
2. Write component using ONLY those values
3. Verify every StyleSheet property before moving on

**Why bottom-up:** Top-down causes layout drift — small parent padding errors compound with child spacing, making everything off by 4-8px at the bottom.

### 3.4 — Figma → RN conversion table

| Figma property | React Native | Function |
|----------------|-------------|----------|
| `width` | `width: scale(n)` | `scale` |
| `height` | `height: vs(n)` | `vs` |
| `padding-left/right` | `paddingHorizontal: scale(n)` | `scale` |
| `padding-top/bottom` | `paddingVertical: vs(n)` | `vs` |
| `margin-left/right` | `marginHorizontal: scale(n)` | `scale` |
| `margin-top/bottom` | `marginVertical: vs(n)` | `vs` |
| `font-size` | `fontSize: ms(n)` | `ms` |
| `line-height` (px number) | `lineHeight: ms(n)` | `ms` |
| `line-height` **Auto** | **omit lineHeight** — do NOT set | native auto |
| `line-height` (percent, e.g. 150%) | `lineHeight: ms(Math.round(fontSize * 1.5))` | `ms` |
| `letter-spacing` | `letterSpacing: n` | **direct — NO scale** |
| `border-width` | `borderWidth: n` | **direct — NO scale** |
| `border-radius` | `borderRadius: scale(n)` | `scale` |
| `gap` | `gap: scale(n)` | `scale` |
| `opacity` | `opacity: n` | **direct** (0–1) |
| HEX color | `colors.semantic.name` | theme only |
| `box-shadow` | `getShadow('sm'/'md'/'lg')` | Platform-aware |
| `auto layout H` | `flexDirection: 'row'` | + alignItems |
| `auto layout V` | `flexDirection: 'column'` | default |
| `space-between` | `justifyContent: 'space-between'` | |
| `fill container` | `flex: 1` | |
| `hug content` | omit width/height | let content define |
| `fixed size` | explicit `width`/`height` | |
| `Clip content` ON | `overflow: 'hidden'` | **required for borderRadius clipping on iOS** |
| `Clip content` OFF | omit overflow (default) | |

#### Figma Constraints → React Native layout

| Figma constraint | React Native equivalent |
|-----------------|------------------------|
| Left only | `left: scale(x)` + explicit `width` |
| Right only | `right: scale(x)` + explicit `width` |
| Left + Right | `left: scale(x), right: scale(x)` OR `flex: 1, marginHorizontal: scale(x)` |
| Center horizontal | `alignSelf: 'center'` OR `left: 0, right: 0` + `alignItems: 'center'` on parent |
| Scale (proportional) | `width: '88%'` (calculate: nodeWidth / frameWidth * 100) |
| Top only | `top: scale(y)` |
| Top + Bottom | `top: scale(y), bottom: scale(y)` |
| Center vertical | `alignSelf: 'center'` inside column container |

> Extract constraints from `get_design_context` → node's `constraints` field: `{ horizontal: "LEFT_RIGHT", vertical: "TOP" }`

> ⚠️ **vs() scope:** Use `vs()` ONLY for fixed-height blocks that occupy a defined fraction of screen height:
> Header, TabBar, Hero section, full-screen non-scrollable containers.
> **Inside ScrollView/FlatList** — use `scale(n)` for vertical spacing (gap, paddingVertical, card height).
> Using `vs()` on scrollable content stretches items on Pro Max and shrinks them on SE.

### 3.5 — Screen template
```typescript
import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { scale, vs } from '@/utils/scale';
import { colors } from '@/theme/colors';

export const HomeScreen: React.FC = () => {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + scale(16) }]}
        showsVerticalScrollIndicator={false}
      >
        {/* components */}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background.primary },
  scroll: { flex: 1 },
  content: { paddingHorizontal: scale(16), paddingTop: scale(24) },
  // Note: scale() for ScrollView content — vs() is only for fixed-height outer blocks
});
```

### 3.6 — FlatList screen template
```typescript
import React from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { scale, vs } from '@/utils/scale';
import { colors } from '@/theme/colors';

interface Item { id: string }

export const ListScreen: React.FC<{ data: Item[] }> = ({ data }) => {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <FlatList
        data={data}
        renderItem={({ item }) => <View style={styles.item} />}
        keyExtractor={(item) => item.id}
        contentContainerStyle={[styles.listContent, { paddingBottom: insets.bottom + scale(16) }]}
        showsVerticalScrollIndicator={false}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background.primary },
  listContent: { paddingHorizontal: scale(16), paddingTop: scale(16) },
  item: { /* match Figma card design */ },
  separator: { height: scale(12) },
  // Note: scale() for FlatList content spacing — vs() is only for fixed-height outer blocks
});
```

### 3.7 — Component template
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
  label, onPress, variant = 'primary', disabled = false,
}) => (
  <TouchableOpacity
    style={[styles.root, styles[variant], disabled && styles.disabled]}
    onPress={onPress}
    disabled={disabled}
    activeOpacity={0.8}
  >
    <Text style={[styles.label, disabled && styles.labelDisabled]}>{label}</Text>
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
  primary: { backgroundColor: colors.primary.default },
  secondary: {
    backgroundColor: colors.background.secondary,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  disabled: { backgroundColor: colors.primary.disabled },
  label: { ...typography.button, color: colors.text.inverse },
  labelDisabled: { color: colors.text.disabled },
});
```

### 3.8 — TextInput template
```typescript
import React, { useState } from 'react';
import { StyleSheet, TextInput as RNTextInput, View, Text } from 'react-native';
import { scale, vs } from '@/utils/scale';
import { colors } from '@/theme/colors';
import { typography } from '@/theme/typography';

interface InputProps {
  label?: string;
  placeholder?: string;
  value: string;
  onChangeText: (text: string) => void;
  error?: string;
}

export const Input: React.FC<InputProps> = ({ label, placeholder, value, onChangeText, error }) => {
  const [focused, setFocused] = useState(false);
  return (
    <View style={styles.wrapper}>
      {label && <Text style={styles.label}>{label}</Text>}
      <RNTextInput
        style={[styles.input, focused && styles.inputFocused, error && styles.inputError]}
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
  wrapper: { gap: vs(6) },
  label: { ...typography.body2, color: colors.text.secondary },
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
  inputFocused: { borderColor: colors.border.focused },
  inputError: { borderColor: colors.status.error },
  error: { ...typography.caption, color: colors.status.error },
});
```

### 3.9 — Shadow pattern
```typescript
import { getShadow, createShadow } from '@/theme/shadows';

// Use preset token (defined in shadows.ts during Phase 2):
card: {
  ...getShadow('card'),
  backgroundColor: colors.background.primary, // REQUIRED — shadows need background
}

// One-off shadow (if this shadow doesn't repeat elsewhere):
specialCard: {
  ...createShadow({ blur: 24, offsetY: 10, opacity: 0.10, color: '#1B1F2A' }),
  backgroundColor: colors.background.primary,
}
```

**Conversion reminder:** `shadowRadius = figmaBlur / 2` — already applied inside `createShadow`.

### 3.10 — Font pattern
```typescript
// Preferred — use typography spread:
text: { ...typography.body1, color: colors.text.primary }

// Manual Platform.select (non-standard fonts):
import { Platform } from 'react-native';
text: {
  fontSize: ms(16),
  lineHeight: ms(24),
  fontFamily: Platform.select({ ios: 'CustomFont-Regular', android: 'CustomFont-Regular', default: 'System' }),
}
```

### 3.11 — Using assets in code

```typescript
// SVG icon (preferred):
import HomeSvg from '@/assets/icons/icon-home.svg';
<HomeSvg width={scale(24)} height={scale(24)} fill={colors.text.primary} />

// PNG icon (fallback):
<Image
  source={require('@/assets/icons/icon-home.png')}
  style={{ width: scale(24), height: scale(24) }}  // ALWAYS set explicit dimensions
  resizeMode="contain"
/>

// Photo / illustration:
<Image
  source={require('@/assets/images/hero.png')}
  style={{ width: '100%', height: vs(200) }}  // ALWAYS set explicit dimensions
  resizeMode="cover"
/>
```

**NEVER use Figma URLs — always locally saved assets via `require()`.**

### 3.12 — overflow: hidden

iOS does NOT clip children at `borderRadius` without `overflow: 'hidden'`. Always add it when:
- View has `borderRadius` AND children that must be clipped (images, gradients, inner content)
- `LinearGradient` has `borderRadius`
- `Image` is inside a rounded View and must fill it

```typescript
// ❌ iOS shows square corners for the image despite borderRadius on container
card: { borderRadius: scale(16), backgroundColor: colors.background.primary }

// ✅ Children are clipped correctly
card: { borderRadius: scale(16), overflow: 'hidden', backgroundColor: colors.background.primary }

// ✅ LinearGradient with borderRadius
<LinearGradient
  colors={['#3870E0', '#1CAAFE']}
  style={{ borderRadius: scale(12), overflow: 'hidden', padding: scale(16) }}
>
  <Text style={styles.label}>Button</Text>
</LinearGradient>
```

> Figma "Clip content" = ON → add `overflow: 'hidden'`
> Any borderRadius on a View that contains Image/Gradient → add `overflow: 'hidden'`

### 3.13 — Mixed inline text styles (partial bold, colored word)

Figma allows different styles on parts of a text node (e.g., bold word in a sentence, colored price in a label). RN handles this with nested `<Text>` components — NOT with a single Text + StyleSheet.

```typescript
// Figma: "Pay {bold}$99{/bold} today"
<Text style={styles.body}>
  Pay{' '}
  <Text style={styles.price}>$99</Text>
  {' '}today
</Text>

// Figma: "Welcome back, {colored}John{/colored}"
<Text style={styles.greeting}>
  Welcome back,{' '}
  <Text style={styles.name}>John</Text>
</Text>

const styles = StyleSheet.create({
  body:     { ...typography.body1, color: colors.text.primary },
  price:    { ...typography.body1, fontWeight: '700', color: colors.primary.default },
  greeting: { ...typography.h3, color: colors.text.primary },
  name:     { ...typography.h3, color: colors.primary.default },
});
```

Detection: in `get_design_context`, a TEXT node with `characterStyleOverrides` or multiple style entries → use nested Text.

---

## PHASE 4 — SELF-REVIEW & VALIDATION

> MANDATORY. Do NOT skip. Do NOT say "looks good" without running it.

### 4.1 — Value audit

After ALL components are implemented, verify every StyleSheet value against the extraction map.

**For screens with ≤ 50 style values — full table:**
```
VERIFICATION: {ComponentName}
┌─────────────────────┬──────────┬───────────────────┬────────┐
│ Property            │ Figma px │ Code              │ Status │
├─────────────────────┼──────────┼───────────────────┼────────┤
│ width               │ 343      │ scale(343)        │ ✓      │
│ height              │ 52       │ vs(52)            │ ✓      │
│ paddingHorizontal   │ 16       │ scale(16)         │ ✓      │
│ fontSize            │ 16       │ ms(16)            │ ✓      │
│ letterSpacing       │ -0.3     │ -0.3              │ ✓      │
│ borderRadius        │ 12       │ scale(12)         │ ✓      │
│ backgroundColor     │ #007AFF  │ colors.primary    │ ✓      │
│ borderWidth         │ 1        │ 1 (direct)        │ ✓      │
└─────────────────────┴──────────┴───────────────────┴────────┘
```

**For screens with > 50 style values — prioritized check:**
- **HIGH (verify every value):** colors, fontSize, fontWeight, borderRadius, padding/margin
- **MEDIUM (spot-check 50%):** gap, lineHeight, letterSpacing
- **LOW (structure check only):** flex direction, alignItems, justifyContent

Fix every ✗ before proceeding.

### 4.2 — Asset & pattern audit

**Emoji audit:**
```bash
grep -rn '[^\x00-\x7F]' src/components/ src/screens/ | grep -v '\.test\.'
```
For each emoji: is it present in the Figma TEXT node?
- YES → KEEP (it's real text content)
- NO → REPLACE with exported PNG icon

**CSS shape audit:**
- `transform: [{ rotate:` in icon/arrow context → should be exported PNG
- Nested Views simulating circles/shapes → should be Image export

**Duplicate pattern audit:**
- Same StyleSheet block in 2+ files → extract to shared atom

### 4.3 — Structure checklist

- [ ] Every screen uses `useSafeAreaInsets()` — no hardcoded notch offset
- [ ] Every shadow has `backgroundColor` on the same View
- [ ] Views with borderRadius + children (images, gradients) have `overflow: 'hidden'`
- [ ] Figma "Clip content" ON → `overflow: 'hidden'` in code
- [ ] Every font uses `Platform.select` or `typography.*` spread
- [ ] Zero hex colors in StyleSheet (only `colors.*` tokens)
- [ ] Zero bare numbers (only `scale/vs/ms()` + exceptions: letterSpacing, borderWidth, opacity)
- [ ] `activeOpacity` on every TouchableOpacity
- [ ] `showsVerticalScrollIndicator={false}` on ScrollView/FlatList
- [ ] `keyExtractor` on every FlatList (not array index)
- [ ] `placeholderTextColor` on every TextInput
- [ ] All `<Image>` have explicit `width` + `height`
- [ ] No emoji icon placeholders
- [ ] No CSS hacks for geometric icons
- [ ] No hidden Figma layers rendered (`visible: false` → absent from code, `opacity: 0` → absent unless animated)

### 4.4 — Add DebugOverlay
```typescript
import { DebugOverlay } from '@/utils/DebugOverlay';

// Inside root View:
{__DEV__ && <DebugOverlay source={require('@/assets/figma/HomeScreen.png')} />}
```

### 4.5 — Fix loop

If verification fails:
1. Find value from extraction map (NOT from memory)
2. If marked `"INCOMPLETE"` → infer from context first. Re-call MCP only as last resort.
3. Fix code → re-run verification table for that component.

---

## PHASE 5 — VISUAL VALIDATION LOOP

> **MANDATORY when simulatorMCP is not null (detected in Phase 0.0.1).**
> The screen is NOT done until this loop passes.
> Target: **≥ 95% visual match** with the Figma design.
> (99%+ is the goal; 95% is the minimum gate to proceed.)

### 5.1 — Detect available tools at runtime

**Do NOT assume tool names.** At the start of Phase 5, determine which tools work:

```
# Try mobile-mcp first:
mobile_take_screenshot()
→ if succeeds: use mobile-mcp tool set

# If that fails, try ios-simulator MCP:
screenshot(output_path: "/tmp/test.png")
→ if succeeds: use ios-simulator tool set

# If both fail: use xcrun fallback
xcrun simctl io booted screenshot /tmp/test.png
```

**mobile-mcp tools:**
- Screenshot: `mobile_take_screenshot()`
- Tap: `mobile_click_on_screen_at_coordinates(x, y)`
- Swipe: `mobile_swipe_on_screen(direction, ...)`
- Launch: `mobile_launch_app(bundle_id)`

**ios-simulator MCP tools:**
- Screenshot: `screenshot(output_path: "/tmp/screen.png")`
- Tap: `ui_tap(x, y)`
- Swipe: `ui_swipe(x_start, y_start, x_end, y_end, duration)`
- Launch: `launch_app(bundle_id)`

**xcrun fallback (no MCP):**
```bash
xcrun simctl io booted screenshot /tmp/screen.png
```

### 5.2 — Prerequisites

- iOS Simulator booted: `xcrun simctl boot "iPhone 16"`
- App running in simulator (Expo/bare RN dev server)
- Figma reference saved at `src/assets/figma/{ScreenName}_design.png`

**Android:** if an Android emulator is running and `mobile-mcp` is connected, run the same loop on Android. Note platform-specific differences (font rendering, status bar, elevation vs shadow).

### 5.3 — Navigate and screenshot

Navigate to the implemented screen, then take a screenshot. Save to `/tmp/{ScreenName}_sim_{N}.png`.

### 5.4 — Visual comparison

**Step 1 — Objective pixel diff (MANDATORY, run first):**

```bash
pip3 install Pillow numpy -q 2>/dev/null
SKILL_DIR=$(find ~/.claude/skills -name "pixel-diff.py" 2>/dev/null | head -1)
python3 "$SKILL_DIR" \
  src/assets/figma/{ScreenName}_design.png \
  /tmp/{ScreenName}_sim_{N}.png \
  /tmp/{ScreenName}_diff_{N}.png
```

Script outputs exact `Match: XX.X%`. Exit code 0 = ≥95%, exit code 1 = needs fixes.
Open the diff image: white = matches, bright/colored = discrepancy. See `references/pixel-diff.md` for interpretation.

**% match comes from the script output — NOT from visual AI estimation.**

**Step 2 — Area-by-area breakdown (fill after viewing diff image):**

Read BOTH images and annotate discrepancies. The diff image shows WHERE to look.

```
VISUAL COMPARISON: {ScreenName} — Iteration {N}
┌──────────────────────┬────────┬────────────────────────────────────┐
│ Area                 │ Match  │ Discrepancy                        │
├──────────────────────┼────────┼────────────────────────────────────┤
│ Header / NavBar      │ ✓ / ✗  │ e.g., "title 2px too low"          │
│ Section 1            │ ✓ / ✗  │                                    │
│ Section 2            │ ✓ / ✗  │                                    │
│ Cards / List items   │ ✓ / ✗  │                                    │
│ Buttons / CTAs       │ ✓ / ✗  │                                    │
│ Colors               │ ✓ / ✗  │                                    │
│ Typography           │ ✓ / ✗  │                                    │
│ Spacing / gaps       │ ✓ / ✗  │                                    │
│ Border radius        │ ✓ / ✗  │                                    │
│ Shadows / elevation  │ ✓ / ✗  │ (see acceptable diffs in platform-patterns.md) │
│ Bottom / Footer      │ ✓ / ✗  │                                    │
├──────────────────────┼────────┼────────────────────────────────────┤
│ MATCH (from script)  │  ___%  │                                    │
└──────────────────────┴────────┴────────────────────────────────────┘
```

**Scroll to verify below-the-fold content:**
```bash
# ios-simulator MCP swipe up (scroll content down):
ui_swipe(x_start: 195, y_start: 600, x_end: 195, y_end: 200, duration: "0.5")
# Then take another screenshot and compare
```

### 5.5 — Fix and repeat

If match < 95%:
1. List all discrepancies
2. For each: identify component + StyleSheet property → look up correct value from extraction map → fix
3. Wait for hot reload → go to 5.3

**Loop until all rows ✓ and match ≥ 95%.**

### 5.6 — Acceptable exceptions (do NOT count as failures)

- Dynamic content (placeholder vs real text — structure must match)
- System UI (status bar time, battery, signal icons)
- Simulator font antialiasing vs Figma rendering
- Native navigation chrome

### 5.7 — Max iterations

**Maximum 10 iterations.** If after 10 rounds match < 95%:
- Output final comparison table with remaining discrepancies
- Tell user: "Достигнут лимит итераций. Совпадение: {N}%. Оставшиеся расхождения: {list}."
- List specific CSS properties/components that still differ
- Ask if user wants to continue or accept current state

### 5.8 — Zero Figma calls in Phase 5

Phase 5 uses ONLY local files:
- Figma design = local PNG from Step 1.4 (fetched once)
- Simulator screenshot = local, via Simulator MCP
- Extraction map = cached from Step 1.2

**No Figma MCP calls during visual validation.**

---

## PHASE 6 — FINAL GATE

> **MANDATORY for any task that produces code. Task is NOT delivered until this passes.**

### 6.1 — Requirements checklist

```
FINAL GATE: {ScreenName}
═══════════════════════════════════════════════════════════
┌────┬─────────────────────────────────────────────────┬────────┐
│ #  │ Requirement                                     │ Status │
├────┼─────────────────────────────────────────────────┼────────┤
│  1 │ useSafeAreaInsets() — no hardcoded notch        │ ✓ / ✗  │
│  2 │ Zero hex colors in StyleSheet (only colors.*)   │ ✓ / ✗  │
│  3 │ Zero bare numbers (scale/vs/ms, or exceptions)  │ ✓ / ✗  │
│  4 │ Platform.select for fontFamily                  │ ✓ / ✗  │
│  5 │ getShadow() with backgroundColor on same View   │ ✓ / ✗  │
│  6 │ letterSpacing — direct value, no scale()        │ ✓ / ✗  │
│  7 │ borderWidth — direct value, no scale()          │ ✓ / ✗  │
│  8 │ activeOpacity on every TouchableOpacity         │ ✓ / ✗  │
│  9 │ keyExtractor on FlatList (not index)            │ ✓ / ✗  │
│ 10 │ placeholderTextColor on every TextInput         │ ✓ / ✗  │
│ 11 │ showsVerticalScrollIndicator={false}            │ ✓ / ✗  │
│ 12 │ No Tailwind/NativeWind classes                  │ ✓ / ✗  │
│ 13 │ No inline styles with magic numbers             │ ✓ / ✗  │
│ 14 │ No imports from icon packages (use Figma assets)│ ✓ / ✗  │
│ 15 │ Icons exported as SVG or PNG@3x                 │ ✓ / ✗  │
│ 16 │ All assets in src/assets/ (no Figma URLs)       │ ✓ / ✗  │
│ 17 │ Theme tokens used (colors, typography, spacing) │ ✓ / ✗  │
│ 18 │ scale() for horizontal, vs() for vertical       │ ✓ / ✗  │
│ 19 │ ms() only for fontSize / lineHeight / iconSize  │ ✓ / ✗  │
│ 20 │ TypeScript — no `any`, proper types             │ ✓ / ✗  │
│ 21 │ No emoji as UI icon placeholders                │ ✓ / ✗  │
│ 22 │ Complex visuals use Image (not nested Views)    │ ✓ / ✗  │
│ 23 │ Shared patterns extracted to atoms              │ ✓ / ✗  │
│ 24 │ Required libs installed (gradient, svg, etc.)   │ ✓ / ✗  │
├────┼─────────────────────────────────────────────────┼────────┤
│    │ TOTAL                                           │ __/24  │
└────┴─────────────────────────────────────────────────┴────────┘
```

Any ✗ → fix → re-run entire table.

### 6.2 — Value accuracy check

For each generated file, verify StyleSheet values against extraction map.

**Efficient strategy:** Only re-verify files modified during Phase 4/5 fixes. For unchanged files, reference Phase 4 table.

```
VALUE ACCURACY: {ScreenName}
┌──────────────────┬───────────────┬──────────┬────────┐
│ File             │ Total values  │ Matching │ Status │
├──────────────────┼───────────────┼──────────┼────────┤
│ HomeScreen.tsx   │ 34            │ 34       │ 100% ✓ │
│ HomeCard.tsx     │ 22            │ 22       │ 100% ✓ │
│ colors.ts        │ 8             │ 8        │ 100% ✓ │
└──────────────────┴───────────────┴──────────┴────────┘
```

### 6.3 — Visual match confirmation

- Simulator MCP available → take final screenshot, compare with Figma reference, confirm ≥ 95%
- Simulator MCP not available → manually review code against Figma screenshot, list uncertainties

### 6.4 — Gate verdict

All must be true:
- [ ] 6.1 Requirements: 24/24 ✓
- [ ] 6.2 Value accuracy: 100% across all files
- [ ] 6.3 Visual match: ≥ 95% (or manual confirmation)

```
FINAL VERDICT: {ScreenName}
═══════════════════════════════════════════════════
│ Requirements:   24/24 ✓                         │
│ Value accuracy: 88/88 (100%) ✓                  │
│ Visual match:   97% ✓                           │
│                                                 │
│ ████████████████████████████████████ PASSED ✓   │
═══════════════════════════════════════════════════
```

### 6.5 — Gate failed → fix loop

If gate fails at ANY step:
1. List ALL failures with file:line
2. Fix every issue
3. **Re-run ENTIRE Phase 6 from 6.1** — not just the failed step
4. No maximum iterations — task is not delivered until gate passes

### 6.6 — Deliver

After gate passes:
1. Output PASSED verdict
2. List all created/modified files
3. Tell user: "Готово. Все проверки пройдены."

---

## ANTI-PATTERNS — NEVER DO

```typescript
// ❌ Tailwind / NativeWind
<View className="px-4 py-6 rounded-xl bg-blue-500" />

// ❌ Inline styles with magic numbers
<View style={{ padding: 16, backgroundColor: '#3B82F6' }} />

// ❌ Bare numbers in StyleSheet (no scale)
paddingHorizontal: 16

// ❌ Hardcoded hex colors
backgroundColor: '#F9FAFB'

// ❌ Hardcoded notch offset
paddingTop: 44

// ❌ Missing Platform.select for fonts
fontFamily: 'Roboto'  // breaks on iOS

// ❌ Missing elevation for Android shadows
shadowColor: '#000'   // invisible on Android — use getShadow()

// ❌ Icon packages when Figma provides assets
import { HomeIcon } from 'lucide-react-native'

// ❌ scale() on letterSpacing
letterSpacing: scale(-0.3)  // distorts tracking

// ❌ scale() on borderWidth
borderWidth: scale(1)  // fractional border = visual artifacts

// ❌ ms() for spacing
paddingHorizontal: ms(16)  // ms is for fonts only

// ❌ Emoji as icon placeholders (unless it IS the Figma text content)
<Text>{'💎'}</Text>  // use exported PNG instead

// ❌ CSS hacks for geometric icons
<View style={{ borderRightWidth: 2, transform: [{ rotate: '45deg' }] }} />
// ✅ Export the icon PNG from Figma

// ❌ Complex visuals with nested Views
<View style={styles.outerCircle}>
  <View style={styles.middleCircle}>
    <View style={styles.innerCircle} />
  </View>
</View>
// ✅ Export as PNG, use <Image> with touchable overlays if interactive

// ❌ Duplicating patterns across components
// Same PlayButton CSS in FavoriteSection.tsx AND LessonsSection.tsx
// ✅ Extract to src/components/ui/PlayButton.tsx

// ❌ Image without explicit dimensions
<Image source={require('./hero.png')} />  // WILL NOT RENDER
// ✅ Always set width + height
<Image source={require('./hero.png')} style={{ width: scale(321), height: vs(200) }} />
```

---

## WHEN FIGMA MCP RETURNS TAILWIND/JSX

The MCP may return React + Tailwind. **Ignore ALL Tailwind classes.**
Use ONLY the raw px values from the design context → convert via table in 3.4.

---

## FILE PLACEMENT

```
src/
  screens/
    {Name}Screen.tsx          ← SafeArea + ScrollView/FlatList + data wiring
  components/
    ui/                       ← reusable atoms (Button, Input, Badge, Avatar)
    {feature}/                ← feature-specific composites
  theme/
    colors.ts
    typography.ts
    spacing.ts
    radius.ts
    shadows.ts
    index.ts                  ← barrel export
  utils/
    scale.ts                  ← scale(), vs(), ms()
    DebugOverlay.tsx
  assets/
    figma/                    ← Figma reference screenshots
    icons/                    ← downloaded Figma icons
    images/                   ← downloaded Figma images
```

---

## INVOCATION EXAMPLES

**Figma link:**
> "Верстай HomeScreen по https://figma.com/design/abc/App?node-id=1-2"
→ Phase 0 → 1 → 2 → 3 → 4 → 5 → **6 (final gate)**

**Single component:**
> "Добавь компонент карточки из Figma https://..."
→ Phase 0 → 1 → 3 → 4 → **6 (final gate)**

**Theme sync only:**
> "Обнови тему из Figma Variables"
→ Phase 1.5 → Phase 2 → done (no Phase 6)

**Visual validation only:**
> "Проверь совпадение с дизайном"
→ Phase 5 → **6 (final gate)**

**Selected nodes:**
> "Верстай выделенное"
→ get_selection → Phase 0 → 1 → 2 → 3 → 4 → 5 → **6**

**Phase 6 is MANDATORY for any task producing code.**
