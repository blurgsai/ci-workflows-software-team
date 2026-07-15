import js from '@eslint/js'
import boundaries from 'eslint-plugin-boundaries'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  { ignores: ['dist', 'node_modules', 'src/vite-env.d.ts'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
      boundaries,
    },
    settings: {
      'boundaries/include': ['src/**/*'],
      'boundaries/ignore': ['src/**/*.test.*', 'src/**/*.spec.*'],
      'boundaries/elements': [
        { type: 'feature', pattern: 'src/features/*/index.ts', mode: 'full', capture: ['feature'] },
        {
          type: 'feature-internal',
          pattern: 'src/features/*/{api,model,hooks,ui}/**',
          mode: 'full',
          capture: ['feature'],
        },
        { type: 'shared', pattern: 'src/shared/**', mode: 'full' },
        { type: 'app', pattern: 'src/app/**', mode: 'full' },
        { type: 'root', pattern: 'src/main.tsx', mode: 'full' },
      ],
      'import/resolver': {
        typescript: {
          project: './tsconfig.app.json',
        },
        node: {
          extensions: ['.js', '.jsx', '.ts', '.tsx'],
        },
      },
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': [
        'warn',
        { allowConstantExport: true },
      ],
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'boundaries/element-types': [
        'error',
        {
          default: 'disallow',
          rules: [
            { from: ['root'], allow: ['app', 'shared', 'feature'] },
            { from: ['app'], allow: ['app', 'feature', 'shared'] },
            { from: ['feature'], allow: ['feature-internal', 'shared'] },
            {
              from: ['feature-internal'],
              allow: [
                ['feature-internal', { feature: '{{ from.feature }}' }],
                'shared',
              ],
            },
            { from: ['shared'], allow: ['shared'] },
          ],
        },
      ],
      'boundaries/entry-point': [
        'error',
        {
          default: 'disallow',
          rules: [
            {
              target: 'feature',
              allow: '**/index.ts',
            },
            {
              target: 'feature-internal',
              allow: '**/*',
            },
            {
              target: 'app',
              allow: '**/*',
            },
            {
              target: 'shared',
              allow: '**/*',
            },
            {
              target: 'root',
              allow: '**/*',
            },
          ],
        },
      ],
      'boundaries/no-private': 'off',
      'boundaries/no-unknown-files': 'error',
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: [
                '@features/*/api/*',
                '@features/*/model/*',
                '@features/*/hooks/*',
                '@features/*/ui/*',
              ],
              message:
                'Feature internals must stay behind the feature index.ts barrel.',
            },
          ],
        },
      ],
    },
  },
  {
    ignores: [
      'dist/',
      'node_modules/',
      'build/',
      '*.config.*',
      'eslint.config.*',
      'vite.config.*',
      'tsconfig.*',
      'src/test/**',
    ],
  }
)
