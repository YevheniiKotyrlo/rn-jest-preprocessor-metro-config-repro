// Transforms packages/metro-config/src/index.flow.js with the Babel options jest/preprocessor.js gives a file its
// nodeFiles pattern matches (metro-babel-register's config), under each sourceType, and counts the import and export
// statements left and the require calls made.
//   node source-type.cjs <react-native checkout>
const fs = require('node:fs');
const path = require('node:path');

const [root] = process.argv.slice(2);
const load = name => require(require.resolve(name, {paths: [root]}));
const babel = load('@babel/core');
const metroBabelRegister = load('metro-babel-register');
const {version} = load('metro-babel-register/package.json');
const {only: _, ...nodeBabelOptions} = metroBabelRegister.config([]);

const file = path.join(root, 'packages', 'metro-config', 'src', 'index.flow.js');
const src = fs.readFileSync(file, 'utf8');
console.log(`  metro-babel-register ${version}`);
for (const sourceType of ['script', 'module', 'unambiguous']) {
  const {code} = babel.transformSync(src, {filename: file, sourceType, ...nodeBabelOptions, ast: false});
  const moduleStatements = code.split('\n').filter(line => /^\s*(import|export)\b/.test(line)).length;
  const requireCalls = (code.match(/\brequire\(/g) ?? []).length;
  console.log(
    `  sourceType: '${sourceType}'`.padEnd(29) +
      `import/export statements left: ${moduleStatements}, require calls: ${requireCalls}`,
  );
}
