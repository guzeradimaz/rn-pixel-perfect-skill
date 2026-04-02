import { Dimensions } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Base design dimensions from Figma (default: iPhone 14 = 390×844)
// Update BASE_WIDTH if your Figma frame uses a different width
const BASE_WIDTH = 390;
const BASE_HEIGHT = 844;

/**
 * Horizontal scale — width, paddingHorizontal, marginHorizontal, borderRadius, gap
 */
export const scale = (size: number): number =>
  (size * SCREEN_WIDTH) / BASE_WIDTH;

/**
 * Vertical scale — height, paddingVertical, marginVertical, top, bottom
 */
export const vs = (size: number): number =>
  (size * SCREEN_HEIGHT) / BASE_HEIGHT;

/**
 * Moderate scale — fontSize, lineHeight, icon sizes
 * Factor 0.5 = halfway between no scaling and full horizontal scaling
 */
export const ms = (size: number, factor: number = 0.5): number =>
  size + (scale(size) - size) * factor;

export { SCREEN_WIDTH, SCREEN_HEIGHT, BASE_WIDTH, BASE_HEIGHT };
