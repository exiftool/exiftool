// Type definitions for chai-withintoleranceof
// Project: https://github.com/RmiTtro/chai-withintoleranceof
// Definitions by: Matthew McEachen <https://github.com/mceachen>
// Definitions: https://github.com/DefinitelyTyped/DefinitelyTyped

/// <reference types="chai" />

interface WithinTolerance {
  (expected: number, tol: number | number[], message?: string): Chai.Assertion;
}

declare namespace Chai {
  interface Assertion
    extends LanguageChains, NumericComparison, TypeComparison {
    withinToleranceOf: WithinTolerance;
    withinTolOf: WithinTolerance;
  }
}
