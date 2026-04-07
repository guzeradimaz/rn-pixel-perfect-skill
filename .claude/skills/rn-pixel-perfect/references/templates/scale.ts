import { Dimensions, PixelRatio } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Base design dimensions from Figma (default: iPhone 14 = 390×844)
// Update BASE_WIDTH if your Figma frame uses a different width
const BASE_WIDTH = 390;
const BASE_HEIGHT = 844;

// Round to nearest device pixel — eliminates subpixel accumulation errors
const r = PixelRatio.roundToNearestPixel;

/**
 * Horizontal scale — width, paddingHorizontal, marginHorizontal, borderRadius, gap
 */
export const scale = (size: number): number =>
  r((size * SCREEN_WIDTH) / BASE_WIDTH);

/**
 * Vertical scale — ONLY for fixed-height blocks: Header, TabBar, Hero, non-scrollable layouts.
 * Do NOT use for vertical spacing inside ScrollView/FlatList — use scale() there.
 */
export const vs = (size: number): number =>
  r((size * SCREEN_HEIGHT) / BASE_HEIGHT);

/**
 * Moderate scale — fontSize, lineHeight, icon sizes only
 * Factor 0.5 = halfway between no scaling and full horizontal scaling
 */
export const ms = (size: number, factor: number = 0.5): number =>
  r(size + (scale(size) - size) * factor);

export { SCREEN_WIDTH, SCREEN_HEIGHT, BASE_WIDTH, BASE_HEIGHT };
