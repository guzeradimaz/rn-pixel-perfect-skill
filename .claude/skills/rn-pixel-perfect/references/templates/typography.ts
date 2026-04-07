import { Platform, TextStyle } from 'react-native';
import { ms } from '@/utils/scale';

/**
 * Typography tokens — synced from Figma Text Styles.
 * Always use spread: ...typography.h1
 * NEVER hardcode fontSize/fontFamily in components.
 *
 * Update these values after running Phase 2 (Token Sync) from Figma.
 */

/**
 * iOS uses SF Pro Display for sizes ≥ 20pt, SF Pro Text for smaller.
 * These fonts have different metrics — using the wrong one causes rendering discrepancies.
 */
const iosFontFamily = (size: number) =>
  size >= 20 ? 'SF Pro Display' : 'SF Pro Text';

const fontFamily = (weight: 'Regular' | 'Medium' | 'SemiBold' | 'Bold', size: number = 16) =>
  Platform.select({
    ios: iosFontFamily(size),
    android: `Roboto${weight === 'Regular' ? '' : `-${weight}`}`,
    default: 'System',
  });

export const typography: Record<string, TextStyle> = {
  // Display — SF Pro Display (≥20pt on iOS)
  h1: {
    fontSize: ms(32),
    lineHeight: ms(40),
    fontWeight: '700',
    fontFamily: fontFamily('Bold', 32),
  },
  h2: {
    fontSize: ms(24),
    lineHeight: ms(32),
    fontWeight: '700',
    fontFamily: fontFamily('Bold', 24),
  },
  h3: {
    fontSize: ms(20),
    lineHeight: ms(28),
    fontWeight: '600',
    fontFamily: fontFamily('SemiBold', 20),
  },

  // Body — SF Pro Text (<20pt on iOS)
  body1: {
    fontSize: ms(16),
    lineHeight: ms(24),
    fontWeight: '400',
    fontFamily: fontFamily('Regular', 16),
  },
  body2: {
    fontSize: ms(14),
    lineHeight: ms(20),
    fontWeight: '400',
    fontFamily: fontFamily('Regular', 14),
  },

  // UI
  button: {
    fontSize: ms(16),
    lineHeight: ms(20),
    fontWeight: '600',
    fontFamily: fontFamily('SemiBold', 16),
  },
  caption: {
    fontSize: ms(12),
    lineHeight: ms(16),
    fontWeight: '400',
    fontFamily: fontFamily('Regular', 12),
  },
  overline: {
    fontSize: ms(10),
    lineHeight: ms(14),
    fontWeight: '500',
    fontFamily: fontFamily('Medium', 10),
    textTransform: 'uppercase',
    letterSpacing: 1.5,
  },
} as const;
