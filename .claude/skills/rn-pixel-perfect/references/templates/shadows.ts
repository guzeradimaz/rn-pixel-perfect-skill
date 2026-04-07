import { Platform, ViewStyle } from 'react-native';

/**
 * Create an exact shadow from Figma values.
 *
 * CONVERSION RULES (Figma → iOS):
 *   shadowRadius = figmaBlur / 2
 *   (Figma blur = Gaussian std deviation × 2; iOS shadowRadius = std deviation)
 *
 * ANDROID: elevation is an approximation — Android doesn't support
 * custom blur/color/opacity. Use elevation override if design requires precise match.
 *
 * Usage:
 *   ...createShadow({ blur: 20, offsetY: 8, opacity: 0.12, color: '#1827AB' })
 */
export const createShadow = (params: {
  blur: number;         // Figma shadow "Blur" value
  offsetY: number;      // Figma shadow "Y" value
  offsetX?: number;     // Figma shadow "X" value (default 0)
  opacity: number;      // Figma shadow opacity (0–1)
  color?: string;       // Figma shadow color as hex (default '#000000')
  elevation?: number;   // Android elevation override (auto-calculated if omitted)
}): ViewStyle => {
  const { blur, offsetY, offsetX = 0, opacity, color = '#000000', elevation } = params;
  const autoElevation = Math.max(1, Math.round((Math.abs(offsetY) + blur / 2) * 0.5));

  return Platform.select({
    ios: {
      shadowColor: color,
      shadowOffset: { width: offsetX, height: offsetY },
      shadowOpacity: opacity,
      shadowRadius: blur / 2,
    },
    android: {
      elevation: elevation ?? autoElevation,
    },
    default: {},
  }) as ViewStyle;
};

/**
 * Preset shadows — UPDATE these values from Figma during Phase 2 Token Sync.
 * Default values are placeholders only. Replace with actual Figma shadow values.
 *
 * Usage: ...getShadow('card')
 * Add/rename keys to match your design system.
 */
export const shadowTokens = {
  // Replace with actual values from Figma during Phase 2:
  sm: createShadow({ blur: 4,  offsetY: 1, opacity: 0.05 }),
  md: createShadow({ blur: 8,  offsetY: 2, opacity: 0.08 }),
  lg: createShadow({ blur: 16, offsetY: 4, opacity: 0.10 }),
  xl: createShadow({ blur: 24, offsetY: 8, opacity: 0.12 }),
} as const;

export type ShadowToken = keyof typeof shadowTokens;

export const getShadow = (level: ShadowToken): ViewStyle => shadowTokens[level];
