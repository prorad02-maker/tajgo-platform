'use strict';
const {spawnSync} = require('node:child_process');
const {resolve} = require('node:path');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator is required');
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Auth emulator is required');
const root = resolve(__dirname, '..');
for (const [cwd, files] of [
  ['functions', ['lib/test/rules/**/*.test.js']],
  ['functions', ['lib/test/integration/**/*.test.js']],
  ['notification-functions', ['test/*.test.js']],
  ['legacy-order-functions', ['test/*.test.js']],
]) {
  const result = spawnSync(process.execPath, ['--test', ...files], {
    cwd: resolve(root, cwd), stdio: 'inherit', env: {
      ...process.env,
      TAJGO_FUNCTIONS_EMULATOR_URL:
        'http://127.0.0.1:5001/demo-tajgo/europe-west1/orderCommand',
    },
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
