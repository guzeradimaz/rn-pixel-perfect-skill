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

## PHASE 0 — PROJECT SCAFFOLDING

> Before any coding, verify the project has everything needed.

### Step 0.0 — Check Figma MCP availability
Before calling any Figma tools, verify the MCP is available:
1. Try calling any Figma MCP tool (e.g., `get_design_context` with a test fileKey)
2. If the tool is NOT available (error "tool not found" or similar):
   - Tell the user: "Figma MCP не подключён. Запусти `bash scripts/setup.sh` из папки скилла или добавь вручную в `~/.claude/settings.json`:"
   ```json
   "mcpServers": {
     "figma": {
       "command": "npx",
       "args": ["-y", "figma-developer-mcp"],
       "env": { "FIGMA_ACCESS_TOKEN": "YOUR_TOKEN" }
     }
   }
   ```
   - Token получить: Figma → Settings → Personal Access Tokens → Generate
   - After adding, restart Claude Code for MCP to load
3. If the MCP IS available — proceed to Step 0.1

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

> Run ALL Figma MCP tools BEFORE writing a single line of code.
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

### Step 1.2 — Get design context (primary source)
Call the Figma MCP tool:
```
get_design_context(fileKey, nodeId)
```
This returns layout, spacing, colors, typography, and component hierarchy.
The MCP may return React + Tailwind code — **IGNORE the Tailwind classes**, use only raw px values.

**CRITICAL: Write down a structured extraction map.**
After getting the design context, fill in this JSON structure for EVERY component/layer.
This is your single source of truth — all code values come from here, never from memory.

```json
{
  "screen": "{ScreenName}",
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
- If a value is ambiguous, re-call `get_design_context` for that specific child node
- If MCP data is truncated, note `"MISSING"` and fetch the child node separately
- Frame width ≠ 390 → update `BASE_WIDTH` in `scale.ts` BEFORE coding

### Step 1.3 — Get visual reference (source of truth)
```
get_screenshot(fileKey, nodeId)
```
Save screenshot path — this is the ground truth for Phase 4 validation.
Save the screenshot to `src/assets/figma/{ScreenName}.png` for DebugOverlay.

### Step 1.4 — Get design tokens (if Figma Variables exist)
```
get_variable_defs(fileKey)
```
If Figma Variables are defined, sync them to `src/theme/` in Phase 2.
This step may not return results if the Figma file doesn't use Variables.

### Step 1.5 — Get child nodes for large/complex screens
If design context is truncated or the screen has many sections:
```
get_metadata(fileKey, nodeId)
```
Then fetch each major section separately by its childNodeId.
Plan the component decomposition from this hierarchy.

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

### 3.9 Image from Figma assets
```typescript
import { Image } from 'react-native';

// Figma MCP may provide image URLs — use them directly during development:
<Image
  source={{ uri: figmaAssetUrl }}
  style={{ width: scale(24), height: scale(24) }}
/>

// For SVG assets — react-native-svg:
import { SvgUri } from 'react-native-svg';
<SvgUri width={scale(24)} height={scale(24)} uri={figmaSvgUrl} />

// For production — download assets and use require():
<Image
  source={require('@/assets/icons/icon-name.png')}
  style={{ width: scale(24), height: scale(24) }}
/>
```

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

### 4.4 — Fix loop
If any verification fails:
1. Find the exact Figma value from the extraction map (NOT from memory)
2. If the extraction map has `"MISSING"` — re-call `get_design_context` for that node
3. Fix the code value
4. Re-run the verification table for that component
5. Repeat until all rows show ✓

### 4.5 — Final summary
After all verification passes, output a brief summary:
```
RESULT: {ScreenName}
- Components: 5 created (Header, Card, Button, Badge, ListItem)
- Files: 5 new, 2 updated (colors.ts, typography.ts)
- Tokens: 3 colors added, 1 typography style added
- Verification: 47/47 values match ✓
- DebugOverlay: added
```

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

→ Phase 0 (scaffold) → Phase 1 (all steps) → Phase 2 (sync tokens) → Phase 3 (implement) → Phase 4 (validate)

**User wants a single component:**
> "Добавь компонент карточки из Figma https://..."

→ Phase 0 (check utils exist) → Phase 1 (design_context + screenshot for that node) → Phase 3.5 template → Phase 4.2 checklist

**User wants to sync theme only:**
> "Обнови тему из Figma Variables https://..."

→ Phase 1.4 (get_variable_defs) → Phase 2 (full token sync) → done

**User wants validation only:**
> "Проверь совпадение с дизайном"

→ Phase 4 only (add DebugOverlay, run checklist)

**User provides Figma link without instructions:**
> "https://figma.com/design/abc/App?node-id=1-2"

→ Treat as full screen implementation: Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4
