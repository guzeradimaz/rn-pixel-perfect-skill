# Platform-Specific Patterns

## Shadows — ВСЕГДА оба платформы

```typescript
import { Platform, StyleSheet } from 'react-native';

// ❌ Только iOS (ничего не делает на Android)
shadowColor: '#000',
shadowOffset: { width: 0, height: 4 },
shadowOpacity: 0.1,
shadowRadius: 8,

// ❌ Только Android (ничего не делает на iOS)
elevation: 4,

// ✅ Через getShadow (оба платформы)
...getShadow('md'),

// ✅ Или Platform.select вручную
...Platform.select({
  ios: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
  android: {
    elevation: 4,
  },
}),
```

## Fonts — ВСЕГДА Platform.select

```typescript
// ❌ Один шрифт для обеих платформ
fontFamily: 'Roboto',      // крашнется на iOS
fontFamily: 'SF Pro Text', // не существует на Android

// ✅ Platform.select
fontFamily: Platform.select({
  ios: 'SF Pro Text',
  android: 'Roboto',
  default: 'System',
}),

// ✅ Или через typography токен (уже содержит Platform.select)
...typography.body1,
```

## Кастомные шрифты из Figma

Если дизайнер использует кастомный шрифт (Inter, Poppins, Wix Madefor Display и т.д.):
```typescript
fontFamily: Platform.select({
  ios: 'Inter-Regular',     // название из font file
  android: 'Inter-Regular', // обычно одинаково
}),

// Для bold weight — отдельный файл:
fontFamily: Platform.select({
  ios: 'Inter-SemiBold',
  android: 'Inter-SemiBold',
}),
```

### Установка кастомных шрифтов

#### Expo проекты:
1. Скачай шрифт (.ttf/.otf) — Google Fonts, сайт бренда, или попроси у дизайнера
2. Положи в `assets/fonts/`
3. Вариант А — через плагин (рекомендуется):
   ```json
   // app.json / app.config.js
   {
     "expo": {
       "plugins": [
         ["expo-font", {
           "fonts": [
             "./assets/fonts/WixMadeforDisplay-Regular.ttf",
             "./assets/fonts/WixMadeforDisplay-Medium.ttf",
             "./assets/fonts/WixMadeforDisplay-SemiBold.ttf",
             "./assets/fonts/WixMadeforDisplay-Bold.ttf"
           ]
         }]
       ]
     }
   }
   ```
4. Вариант Б — динамически через `useFonts`:
   ```typescript
   import { useFonts } from 'expo-font';

   const [fontsLoaded] = useFonts({
     'WixMadeforDisplay-Regular': require('./assets/fonts/WixMadeforDisplay-Regular.ttf'),
     'WixMadeforDisplay-Bold': require('./assets/fonts/WixMadeforDisplay-Bold.ttf'),
   });
   if (!fontsLoaded) return null; // splash screen
   ```

#### Bare React Native проекты:
1. Положи шрифты в `src/assets/fonts/`
2. Создай/обнови `react-native.config.js`:
   ```javascript
   module.exports = {
     project: { ios: {}, android: {} },
     assets: ['./src/assets/fonts/'],
   };
   ```
3. Запусти: `npx react-native-asset`
4. **Пересобери приложение** — шрифты требуют native rebuild, hot reload недостаточно

#### Если шрифты ещё НЕ установлены:
Используй системный шрифт как fallback, но **оставь TODO:**
```typescript
fontFamily: Platform.select({
  ios: 'System',      // TODO: Install 'WixMadeforDisplay-Regular'
  android: 'Roboto',  // TODO: Install 'WixMadeforDisplay-Regular'
}),
```
Скажи пользователю: "Дизайн использует шрифт '{FontName}'. Для точного совпадения нужно установить его: инструкция в platform-patterns.md."

## Status Bar

```typescript
import { StatusBar } from 'expo-status-bar'; // Expo
// или
import { StatusBar } from 'react-native'; // bare RN

// Light content (светлый текст) — для тёмных экранов
<StatusBar style="light" />

// Dark content — для светлых экранов
<StatusBar style="dark" />

// Под стиль Figma:
// Смотри на статус-бар в Figma-дизайне — светлый или тёмный?
```

## Safe Area

```typescript
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const MyScreen = () => {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      {/* контент */}
      <View style={{ height: insets.bottom }} /> {/* footer spacing */}
    </View>
  );
};

// Для ScrollView:
<ScrollView
  contentContainerStyle={{
    paddingBottom: insets.bottom + vs(16),
  }}
/>

// НИКОГДА:
paddingTop: 44,  // жёстко для iPhone X
paddingBottom: 34, // жёстко для iPhone X
// Это сломается на всех других устройствах
```

## Keyboard Avoiding

```typescript
import { KeyboardAvoidingView, Platform } from 'react-native';

// Для экранов с TextInput
<KeyboardAvoidingView
  style={styles.container}
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 20}
>
  {/* форма */}
</KeyboardAvoidingView>
```

## TouchableOpacity vs Pressable

```typescript
// TouchableOpacity — классика, работает везде
<TouchableOpacity onPress={onPress} activeOpacity={0.8}>
  <Text>Button</Text>
</TouchableOpacity>

// Pressable — более гибкий, поддерживает pressed state
<Pressable
  onPress={onPress}
  style={({ pressed }) => [
    styles.button,
    pressed && styles.buttonPressed,
  ]}
>
  <Text>Button</Text>
</Pressable>

// hitSlop — увеличивает область нажатия без изменения визуала
// Используй если кнопка < 44pt
<TouchableOpacity
  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
>
```

## Image

```typescript
import { Image } from 'react-native';
// или для лучшей производительности:
import { Image } from 'expo-image'; // Expo

// Из Figma assets (localhost URL):
<Image
  source={{ uri: 'http://localhost:3845/assets/image-abc.png' }}
  style={{ width: scale(200), height: vs(150) }}
  resizeMode="cover"  // cover / contain / stretch / center
/>

// Локальный ресурс:
<Image
  source={require('../assets/images/hero.png')}
  style={{ width: scale(200), height: vs(150) }}
/>

// ВАЖНО: для Image нужна явная ширина И высота
// flex: 1 без размеров = изображение не отобразится
```

## FlatList / SectionList

```typescript
import { FlatList, SectionList } from 'react-native';

// FlatList — для однородных списков
<FlatList
  data={items}
  renderItem={({ item }) => <ItemCard item={item} />}
  keyExtractor={(item) => item.id}
  contentContainerStyle={{
    paddingHorizontal: scale(16),
    paddingTop: scale(16),
    paddingBottom: insets.bottom + scale(16),
  }}
  showsVerticalScrollIndicator={false}
  ItemSeparatorComponent={() => <View style={{ height: scale(12) }} />}
/>

// SectionList — для сгруппированных списков (секции с заголовками)
<SectionList
  sections={[
    { title: 'Section 1', data: items1 },
    { title: 'Section 2', data: items2 },
  ]}
  renderItem={({ item }) => <ItemCard item={item} />}
  renderSectionHeader={({ section }) => (
    <Text style={styles.sectionTitle}>{section.title}</Text>
  )}
  keyExtractor={(item) => item.id}
  contentContainerStyle={{
    paddingBottom: insets.bottom + vs(16),
  }}
  stickySectionHeadersEnabled={false}
/>

// ВАЖНО: для performance:
// - Всегда keyExtractor (не индекс!)
// - getItemLayout если элементы одинаковой высоты
// - initialNumToRender={10} для длинных списков
// - maxToRenderPerBatch={10}
```

## Modal / BottomSheet

```typescript
import { Modal, View, TouchableOpacity } from 'react-native';

// Простой модал:
<Modal
  visible={visible}
  transparent
  animationType="fade"
  onRequestClose={onClose}
>
  <TouchableOpacity
    style={styles.backdrop}
    activeOpacity={1}
    onPress={onClose}
  >
    <View style={styles.modalContent}>
      {/* контент модала */}
    </View>
  </TouchableOpacity>
</Modal>

// Стили:
backdrop: {
  flex: 1,
  backgroundColor: 'rgba(0, 0, 0, 0.5)',
  justifyContent: 'center',
  alignItems: 'center',
},
modalContent: {
  width: scale(343),
  borderRadius: scale(16),
  backgroundColor: colors.background.primary,
  padding: scale(24),
  ...getShadow('xl'),
},

// Для BottomSheet — лучше использовать @gorhom/bottom-sheet
// Не пытайся реализовать сложный bottom sheet вручную
```

## Допустимые расхождения (не считать за баги в Phase 5)

Эти расхождения являются нормой и не должны учитываться при подсчёте % матча:

| Источник расхождения | Описание | Допустимо |
|---------------------|----------|-----------|
| Сглаживание шрифта | Figma рендерит через Electron/web, iOS через CoreText — разная субпиксельная обработка | ≤1px |
| Тени | Figma CSS box-shadow vs iOS shadowRadius — iOS чуть мягче по краям | видимо, но норма |
| Blur-фильтры | Figma blur ≠ `@react-native-community/blur` — разные алгоритмы | видимо, но норма |
| Emoji | Размер emoji-глифов отличается между платформами | ±2-4px |
| Status bar | В Figma нарисована условно, на устройстве — системная | пропускать |
| Системные хром-элементы | Нативный индикатор Home, системные кнопки | пропускать |
| Placeholder text | Симулятор показывает реальный placeholder | не ошибка |
| Время/батарея в статусбаре | Разные значения | пропускать |

При подсчёте % совпадения через pixel-diff скрипт — кропай status bar область (верхние ~50px) из обоих изображений перед сравнением.

## Animations

```typescript
// Для pixel-perfect анимаций — react-native-reanimated (уже в Expo)
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';

// Простой fade:
const opacity = useSharedValue(0);
const style = useAnimatedStyle(() => ({ opacity: opacity.value }));
opacity.value = withTiming(1, { duration: 300 });

// НИКОГДА Animated из react-native для сложных анимаций
// (работает на JS thread, может лагать)
```

## Gradient

### Извлечение из Figma MCP

`get_design_context` возвращает градиентные fills в поле `fills[]`:

```json
{
  "type": "GRADIENT_LINEAR",
  "gradientHandlePositions": [
    { "x": 0.0, "y": 0.5 },
    { "x": 1.0, "y": 0.5 },
    { "x": 0.0, "y": 0.0 }
  ],
  "gradientStops": [
    { "color": { "r": 0.22, "g": 0.44, "b": 0.88, "a": 1.0 }, "position": 0.0 },
    { "color": { "r": 0.11, "g": 0.66, "b": 0.99, "a": 1.0 }, "position": 1.0 }
  ]
}
```

**Конвертация:**

1. **Цвета** (r/g/b — float 0–1 → hex):
```python
# r=0.22, g=0.44, b=0.88, a=1.0
hex_color = f"#{int(r*255):02X}{int(g*255):02X}{int(b*255):02X}"
# → "#3870E0"

# Если alpha < 1: используй rgba()
rgba_color = f"rgba({int(r*255)},{int(g*255)},{int(b*255)},{a:.2f})"
```

2. **Направление** из `gradientHandlePositions`:
```
handle[0] = start point { x, y } (значения 0–1 от ширины/высоты элемента)
handle[1] = end point   { x, y }

→ start = { x: handle[0].x, y: handle[0].y }
→ end   = { x: handle[1].x, y: handle[1].y }

Горизонтальный (→): start={x:0,y:0.5} end={x:1,y:0.5}
Вертикальный (↓):   start={x:0.5,y:0} end={x:0.5,y:1}
Диагональный (↘):   start={x:0,y:0}   end={x:1,y:1}
```

3. **Stops positions** из `gradientStops[].position` (уже 0–1, использовать напрямую)

### Код

```typescript
import { LinearGradient } from 'expo-linear-gradient';
// или: import LinearGradient from 'react-native-linear-gradient';

// Пример: горизонтальный градиент из Figma
<LinearGradient
  colors={['#3870E0', '#1CAAFE']}           // из gradientStops[].color
  locations={[0, 1]}                         // из gradientStops[].position
  start={{ x: 0, y: 0.5 }}                  // из gradientHandlePositions[0]
  end={{ x: 1, y: 0.5 }}                    // из gradientHandlePositions[1]
  style={[styles.gradient, { borderRadius: scale(12) }]}
>
  {/* контент поверх градиента */}
</LinearGradient>

// Вертикальный с прозрачным fade:
<LinearGradient
  colors={['rgba(0,0,0,0)', 'rgba(0,0,0,0.6)']}
  locations={[0, 1]}
  start={{ x: 0, y: 0 }}
  end={{ x: 0, y: 1 }}
  style={StyleSheet.absoluteFillObject}      // overlay поверх Image
/>
```

### Правила:
- НИКОГДА не хардкодить hex в colors — записывать в `colors.*` токены или inline const над компонентом
- `borderRadius` на LinearGradient работает только с `overflow: 'hidden'` на обёртке или прямо на LinearGradient
- Для сложных multi-stop радиальных градиентов (3+ stops, radial) → экспортировать PNG из Figma

### Radial gradient
`react-native-linear-gradient` не поддерживает radial. Если в Figma `GRADIENT_RADIAL`:
→ экспортировать элемент как PNG через `save_screenshots`
