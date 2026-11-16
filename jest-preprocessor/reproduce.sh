#!/usr/bin/env bash
# Runs a Jest test that requires @react-native/metro-config in a react/react-native checkout where `yarn install` has
# run, and reports whether jest/preprocessor.js leaves the package's `import` statements in place.
#
#   ./jest-preprocessor/reproduce.sh <react-native checkout>
#
# Exits 1 while the test fails with "SyntaxError: Cannot use import statement outside a module" in
# packages/metro-config, 0 once it passes, and 2 when a step fails or the test fails another way.
# The test is copied into packages/react-native/src/private/__repro_metro_config__/ and removed on exit.
# The checkout's path is printed as <react-native>.

set -u

# The folder bash is in, as the OS names it: `pwd -W` in Git Bash on Windows, `pwd` elsewhere.
native_pwd() {
  pwd -W 2>/dev/null || pwd
}

summary() {
  echo "SUMMARY: $*"
}

here=$(cd "$(dirname "$0")" && native_pwd) || exit 2
rn=${1:-}
if [ -z "$rn" ] || [ ! -f "$rn/jest/preprocessor.js" ] || [ ! -f "$rn/node_modules/jest/package.json" ]; then
  echo "usage: $0 <react/react-native checkout after yarn install>" >&2
  summary "no react/react-native checkout with node_modules at '$rn'"
  exit 2
fi
rn=$(cd "$rn" && native_pwd) || exit 2
rn_backslashed=${rn//\//\\}

# Prints stdin with the checkout's path, in either slash, replaced by <react-native>.
redact() {
  R1="$rn" R2="$rn_backslashed" awk '
    function rep(s, r,    out, i) {
      out = ""
      while ((i = index(s, r)) > 0) {
        out = out substr(s, 1, i - 1) "<react-native>"
        s = substr(s, i + length(r))
      }
      return out s
    }
    { print rep(rep($0, ENVIRON["R2"]), ENVIRON["R1"]); fflush() }'
}

sha=$(git -C "$rn" rev-parse --short=11 HEAD 2>/dev/null) || sha="(not a git checkout)"
day=$(git -C "$rn" log -1 --format=%cs HEAD 2>/dev/null) || day="?"
node_version=$(node -v) || { summary "node did not run"; exit 2; }
yarn_version=$(cd "$rn" && yarn --version) || { summary "yarn did not run"; exit 2; }
jest_version=$(cd "$rn" && node -p "require('jest/package.json').version") || { summary "jest's version did not read"; exit 2; }
os=$(node -p "require('os').type() + ' ' + require('os').release() + ' ' + process.arch") || exit 2
echo "react/react-native $sha ($day), Node $node_version, Yarn $yarn_version, Jest $jest_version, $os"

probe_dir_rel=packages/react-native/src/private/__repro_metro_config__
test_rel=$probe_dir_rel/__tests__/metro-config-from-source-test.js
if [ -e "$rn/$probe_dir_rel" ]; then
  summary "$probe_dir_rel already exists in the checkout; remove it and run again"
  exit 2
fi
out=$(mktemp) || exit 2
trap 'rm -rf "$rn/$probe_dir_rel" "$out"' EXIT
if ! mkdir -p "$rn/$probe_dir_rel/__tests__" || ! cp "$here/metro-config-from-source-test.js" "$rn/$test_rel"; then
  summary "could not copy the test into the checkout"
  exit 2
fi
echo
echo "Step 1: copied metro-config-from-source-test.js to $test_rel:"
sed -e 's/^/  /' -e 's/ *$//' "$here/metro-config-from-source-test.js"

echo
echo "Step 2: yarn jest $test_rel"
(cd "$rn" && FORCE_COLOR=0 yarn --silent jest "$test_rel") >"$out" 2>&1
jest_status=$?
redact <"$out"
echo "(jest exited $jest_status)"

echo
echo "Step 3: packages/metro-config/src/index.flow.js through the Babel options jest/preprocessor.js gives a file nodeFiles matches, under each sourceType:"
step3=$(node "$here/source-type.cjs" "$rn" 2>&1)
step3_status=$?
echo "$step3" | redact
if [ "$step3_status" -ne 0 ]; then
  summary "step 3 failed (exit $step3_status)"
  exit 2
fi

echo
if grep -q 'SyntaxError: Cannot use import statement outside a module' "$out" &&
  grep -Eq 'metro-config[\\/]src[\\/]index\.flow\.js' "$out"; then
  summary "defect shows on react/react-native $sha: a Jest test that requires @react-native/metro-config fails with \"SyntaxError: Cannot use import statement outside a module\" in packages/metro-config/src/index.flow.js, whose import statements jest/preprocessor.js left in place"
  exit 1
fi
if [ "$jest_status" -eq 0 ] && grep -Eq 'Tests: +1 passed, 1 total' "$out"; then
  summary "fixed on react/react-native $sha: the Jest test that requires @react-native/metro-config passes"
  exit 0
fi
summary "inconclusive on react/react-native $sha: jest exited $jest_status without the SyntaxError in packages/metro-config; its output is above"
exit 2
