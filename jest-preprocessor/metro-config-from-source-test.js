/**
 * @flow strict-local
 * @format
 */

it('loads @react-native/metro-config from source', () => {
  const {getDefaultConfig} = require('@react-native/metro-config');
  expect(typeof getDefaultConfig).toBe('function');
});
