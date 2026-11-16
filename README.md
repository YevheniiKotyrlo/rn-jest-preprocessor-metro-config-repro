# React Native's Jest cannot require `@react-native/metro-config`

This repository was made from React Native's reproducer template. The reproduction is in `jest-preprocessor/`; the template's `ReproducerApp` is unchanged and it does not use it.

`jest-preprocessor/reproduce.sh` takes a `react/react-native` checkout where `yarn install` has run, copies `jest-preprocessor/metro-config-from-source-test.js` into it, runs that test with `yarn jest`, and removes it again:

```sh
git clone https://github.com/react/react-native
(cd react-native && yarn install)
./jest-preprocessor/reproduce.sh react-native
```

The test only requires `@react-native/metro-config`. In the repository's Jest setup it fails with `SyntaxError: Cannot use import statement outside a module` in `packages/metro-config/src/index.flow.js`: `jest/preprocessor.js` sends every file under a `metro-*` folder through `metro-babel-register`'s options with `sourceType: 'script'`, which leaves its `import` and `export` statements in place. The script's step 3 runs the same file through the same options under each `sourceType` and counts the statements left.

It exits 1 while the test fails with that `SyntaxError`, 0 once it passes, and 2 when a step fails or the test fails another way, and it ends with a `SUMMARY:` line. The checkout's path is printed as `<react-native>`.
