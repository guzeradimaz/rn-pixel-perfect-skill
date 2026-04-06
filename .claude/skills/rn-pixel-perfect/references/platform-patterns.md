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
    paddingTop: vs(16),
    paddingBottom: insets.bottom + vs(16),
  }}
  showsVerticalScrollIndicator={false}
  ItemSeparatorComponent={() => <View style={{ height: vs(12) }} />}
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

```typescript
// React Native не имеет встроенных градиентов
// Используй expo-linear-gradient или react-native-linear-gradient

import { LinearGradient } from 'expo-linear-gradient';

<LinearGradient
  colors={[colors.primary.default, colors.primary.pressed]}
  start={{ x: 0, y: 0 }}
  end={{ x: 1, y: 0 }}
  style={styles.gradientButton}
>
  <Text style={styles.buttonText}>Button</Text>
</LinearGradient>

// Стиль для градиента — те же правила: scale/vs, borderRadius через scale
```
