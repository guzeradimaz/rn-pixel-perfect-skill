import { scale } from '@/utils/scale';

/**
 * Border radius tokens — synced from Figma corner radius values.
 * Use: borderRadius: radius.md
 * NEVER hardcode borderRadius in components.
 *
 * Update these values after running Phase 2 (Token Sync) from Figma.
 */
export const radius = {
  none: 0,
  xs: scale(4),
  sm: scale(8),
  md: scale(12),
  lg: scale(16),
  xl: scale(24),
  full: scale(9999), // pill / circle
} as const;
