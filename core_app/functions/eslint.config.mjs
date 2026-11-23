// ESLint flat config for Carnama Cloud Functions — batch CI-3 (master W1.5).
// Style-level lint only: zero behavior change. Type safety remains `tsc`'s job
// (deliberately no `parserOptions.project`; see batch spec §3.5 honest residuals).
//
// eslint-config-google@0.14.0 ships in the legacy eslintrc format, so it is
// translated to flat config via FlatCompat (bundled with ESLint 9 as
// `@eslint/eslintrc` — no extra package.json dependency).
import { FlatCompat } from '@eslint/eslintrc';
import tsPlugin from '@typescript-eslint/eslint-plugin';
import tsParser from '@typescript-eslint/parser';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const compat = new FlatCompat({ baseDirectory: here });

// `valid-jsdoc` and `require-jsdoc` were REMOVED from ESLint core in v9 but are
// still referenced by eslint-config-google@0.14.0; ESLint rejects unknown rules,
// so they are dropped during translation. This is a compatibility removal, not
// a style override: the rules no longer exist, and their supported replacement
// (eslint-plugin-jsdoc) is outside this batch's sanctioned dependency set.
// Recorded in FIX_VERIFICATION_cline-task-2.md.
const google = compat.extends('eslint-config-google').map((config) => {
  if (config.rules) {
    delete config.rules['valid-jsdoc'];
    delete config.rules['require-jsdoc'];
  }
  return config;
});

export default [
  ...google,
  {
    files: ['src/**/*.ts'],
    plugins: {
      '@typescript-eslint': tsPlugin,
    },
    languageOptions: {
      parser: tsParser,
    },
    rules: {
      // The JS `no-unused-vars` heuristic mis-fires on TypeScript syntax;
      // the TS-aware rule replaces it. (`tsc --noEmit` with tsconfig's
      // `noUnusedLocals: true` remains the hard gate for unused locals.)
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['error', {args: 'none'}],
      // Recorded override (batch spec §3.5 residual clause): google's 80-col
      // limit conflicts with the codebase's existing ~100-col TS style, and
      // reflowing 88 lines of money-integrity code is high-churn/zero-value.
      // The rule stays active at 100; every line >100 is fixed in-source
      // except one template-literal line (recorded inline disable).
      'max-len': ['error', {code: 100, tabWidth: 2, ignoreUrls: true}],
    },
  },
];
