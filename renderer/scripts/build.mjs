import * as esbuild from 'esbuild';

const watch = process.argv.includes('--watch');

const shared = {
  entryPoints: ['src/index.js'],
  bundle: true,
  sourcemap: true,
  target: ['es2019'],
};

const builds = [
  {
    ...shared,
    format: 'esm',
    outfile: 'dist/index.js',
  },
  {
    ...shared,
    format: 'cjs',
    outfile: 'dist/index.cjs',
  },
  {
    ...shared,
    format: 'iife',
    globalName: 'RichTextEditorRenderer',
    outfile: 'dist/index.global.js',
  },
];

if (watch) {
  const contexts = await Promise.all(builds.map((options) => esbuild.context(options)));
  await Promise.all(contexts.map((context) => context.watch()));
  console.log('watching renderer builds...');
} else {
  await Promise.all(builds.map((options) => esbuild.build(options)));
  console.log('renderer builds complete');
}
