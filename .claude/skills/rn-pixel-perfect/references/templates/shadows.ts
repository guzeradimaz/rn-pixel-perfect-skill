import { Platform, ViewStyle } from 'react-native';

type ShadowLevel = 'none' | 'sm' | 'md' | 'lg' | 'xl';

const shadowMap: Record<
  ShadowLevel,
  { offset: number; radius: number; opacity: number; elevation: number }
> = {
  none: { offset: 0, radius: 0, opacity: 0, elevation: 0 },
  sm: { offset: 1, radius: 2, opacity: 0.05, elevation: 1 },
  md: { offset: 2, radius: 4, opacity: 0.1, elevation: 3 },
  lg: { offset: 4, radius: 8, opacity: 0.15, elevation: 6 },
  xl: { offset: 8, radius: 16, opacity: 0.2, elevation: 12 },
};

/**
 * Cross-platform shadow — returns iOS shadowColor/Offset/Opacity/Radius
 * AND Android elevation in a single spread.
 *
 * Usage: ...getShadow('md')
 * IMPORTANT: container MUST have backgroundColor for shadows to render.
 */
export const getShadow = (level: ShadowLevel): ViewStyle => {
  const s = shadowMap[level];
  return Platform.select({
    ios: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: s.offset },
      shadowOpacity: s.opacity,
      shadowRadius: s.radius,
    },
    android: {
      elevation: s.elevation,
    },
    default: {},
  }) as ViewStyle;
};
