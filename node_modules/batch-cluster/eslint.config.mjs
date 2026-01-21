// eslint.config.mjs
import eslint from "@eslint/js";
import importPlugin from "eslint-plugin-import";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: ["dist/", "node_modules/", "**/*.d.ts", "coverage/", "docs/"],
  },
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        project: "./tsconfig.json",
        ecmaVersion: "latest",
        sourceType: "module",
      },
      globals: globals.node,
    },
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  ...tseslint.configs.stylistic,
  {
    files: ["src/**/*.ts"],
    ignores: ["src/**/*.spec.ts", "src/test.ts"], // Exclude test files from strict rules
    plugins: {
      import: importPlugin,
    },
    rules: {
      // Project-specific preferences that differ from defaults
      eqeqeq: ["error", "always", { null: "ignore" }], // Allow == null for defensive coding
      "@typescript-eslint/no-unnecessary-condition": "off", // We want defensive null checks
      "@typescript-eslint/prefer-optional-chain": "off", // Prefer explicit null checks for clarity

      // Import rules
      "import/no-cycle": "error", // TypeScript can't catch circular imports

      // Stricter than defaults
      "no-console": "error",
    },
  },
  {
    files: ["src/**/*.spec.ts", "src/test.ts", "src/_chai.spec.ts"],
    plugins: {
      import: importPlugin,
    },
    rules: {
      // Relax rules that are problematic for test files
      "@typescript-eslint/explicit-function-return-type": "off",
      "@typescript-eslint/explicit-module-boundary-types": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unused-expressions": "off",
      "@typescript-eslint/no-non-null-assertion": "off",
      "@typescript-eslint/no-floating-promises": "off",
      "@typescript-eslint/switch-exhaustiveness-check": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-unnecessary-type-assertion": "off",
      "@typescript-eslint/await-thenable": "off",
      "@typescript-eslint/no-misused-promises": "off",
      "@typescript-eslint/restrict-plus-operands": "off",
      "no-console": "off",
      "@typescript-eslint/no-var-requires": "off",

      // Re-enable one valuable rule that's safe for tests
      "import/no-cycle": "error", // Circular imports are bad even in tests
    },
  },
);
