/**
 * Semantic color tokens — synced from Figma Variables.
 * NEVER use hex values directly in components.
 * Always reference: colors.primary.default, colors.text.primary, etc.
 *
 * Update these values after running Phase 2 (Token Sync) from Figma.
 */
export const colors = {
  primary: {
    default: '#007AFF',
    pressed: '#0056B3',
    disabled: '#B0D4FF',
  },
  background: {
    primary: '#FFFFFF',
    secondary: '#F2F2F7',
    tertiary: '#E5E5EA',
  },
  text: {
    primary: '#000000',
    secondary: '#8E8E93',
    placeholder: '#C7C7CC',
    inverse: '#FFFFFF',
    disabled: '#C7C7CC',
  },
  border: {
    default: '#E5E5EA',
    focused: '#007AFF',
  },
  status: {
    success: '#34C759',
    error: '#FF3B30',
    warning: '#FF9500',
    info: '#5AC8FA',
  },
} as const;
