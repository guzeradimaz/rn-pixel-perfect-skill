import React, { useState } from 'react';
import {
  Image,
  ImageSourcePropType,
  StyleSheet,
  TouchableOpacity,
  View,
  Text,
  Dimensions,
} from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface DebugOverlayProps {
  /** require('../assets/figma/ScreenName.png') */
  source: ImageSourcePropType;
  /** Initial opacity 0–1. Default 0.3 */
  initialOpacity?: number;
}

/**
 * DEV ONLY — overlay Figma screenshot on top of the screen for pixel-perfect comparison.
 *
 * Usage:
 * ```tsx
 * {__DEV__ && <DebugOverlay source={require('../assets/figma/HomeScreen.png')} />}
 * ```
 *
 * Tap the overlay to cycle opacity: 0.3 → 0.5 → 0.7 → hide → 0.3 ...
 */
export const DebugOverlay: React.FC<DebugOverlayProps> = ({
  source,
  initialOpacity = 0.3,
}) => {
  const opacitySteps = [initialOpacity, 0.5, 0.7, 0];
  const [stepIndex, setStepIndex] = useState(0);

  const currentOpacity = opacitySteps[stepIndex];

  const cycleOpacity = () => {
    setStepIndex((prev) => (prev + 1) % opacitySteps.length);
  };

  if (currentOpacity === 0) {
    return (
      <TouchableOpacity
        style={styles.hiddenToggle}
        onPress={cycleOpacity}
        activeOpacity={0.8}
      >
        <Text style={styles.toggleText}>DBG</Text>
      </TouchableOpacity>
    );
  }

  return (
    <TouchableOpacity
      style={[styles.overlay, { opacity: currentOpacity }]}
      onPress={cycleOpacity}
      activeOpacity={currentOpacity}
    >
      <Image
        source={source}
        style={styles.image}
        resizeMode="contain"
      />
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 9999,
  },
  image: {
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  hiddenToggle: {
    position: 'absolute',
    top: 60,
    right: 8,
    zIndex: 9999,
    backgroundColor: 'rgba(255,0,0,0.6)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  toggleText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '700',
  },
});
