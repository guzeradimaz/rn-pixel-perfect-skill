import { scale, vs } from '@/utils/scale';

/**
 * Spacing tokens — synced from Figma spacing variables.
 * Use: spacing.md for horizontal, vSpacing.md for vertical.
 * NEVER hardcode padding/margin values in components.
 *
 * Update these values after running Phase 2 (Token Sync) from Figma.
 */

/** Horizontal spacing — for paddingHorizontal, marginHorizontal, gap */
export const spacing = {
  xxs: scale(4),
  xs: scale(8),
  sm: scale(12),
  md: scale(16),
  lg: scale(24),
  xl: scale(32),
  xxl: scale(48),
} as const;

/** Vertical spacing — for paddingVertical, marginVertical, top, bottom */
export const vSpacing = {
  xxs: vs(4),
  xs: vs(8),
  sm: vs(12),
  md: vs(16),
  lg: vs(24),
  xl: vs(32),
  xxl: vs(48),
} as const;
