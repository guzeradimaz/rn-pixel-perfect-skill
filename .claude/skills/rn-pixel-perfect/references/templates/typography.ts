import { Platform, TextStyle } from 'react-native';
import { ms } from '@/utils/scale';

/**
 * Typography tokens — synced from Figma Text Styles.
 * Always use spread: ...typography.h1
 * NEVER hardcode fontSize/fontFamily in components.
 *
 * Update these values after running Phase 2 (Token Sync) from Figma.
 */

const fontFamily = (weight: 'Regular' | 'Medium' | 'SemiBold' | 'Bold') =>
  Platform.select({
    ios: `SF Pro Text`,
    android: `Roboto${weight === 'Regular' ? '' : `-${weight}`}`,
    default: 'System',
  });

export const typography: Record<string, TextStyle> = {
  // Display
  h1: {
    fontSize: ms(32),
    lineHeight: ms(40),
    fontWeight: '700',
    fontFamily: fontFamily('Bold'),
  },
  h2: {
    fontSize: ms(24),
    lineHeight: ms(32),
    fontWeight: '700',
    fontFamily: fontFamily('Bold'),
  },
  h3: {
    fontSize: ms(20),
    lineHeight: ms(28),
    fontWeight: '600',
    fontFamily: fontFamily('SemiBold'),
  },

  // Body
  body1: {
    fontSize: ms(16),
    lineHeight: ms(24),
    fontWeight: '400',
    fontFamily: fontFamily('Regular'),
  },
  body2: {
    fontSize: ms(14),
    lineHeight: ms(20),
    fontWeight: '400',
    fontFamily: fontFamily('Regular'),
  },

  // UI
  button: {
    fontSize: ms(16),
    lineHeight: ms(20),
    fontWeight: '600',
    fontFamily: fontFamily('SemiBold'),
  },
  caption: {
    fontSize: ms(12),
    lineHeight: ms(16),
    fontWeight: '400',
    fontFamily: fontFamily('Regular'),
  },
  overline: {
    fontSize: ms(10),
    lineHeight: ms(14),
    fontWeight: '500',
    fontFamily: fontFamily('Medium'),
    textTransform: 'uppercase',
    letterSpacing: 1.5,
  },
} as const;
