// src/capabilities-check.ts
// Build-time parity verification: both TUI and Web must implement AllCapabilities.
// If either is missing a method, `deno check src/capabilities-check.ts` will fail.

import type { AllCapabilities } from "./capabilities.ts";
import type { createCapabilities } from "./capabilities-impl.ts";

// Verify that createCapabilities returns AllCapabilities
type _VerifyImpl = ReturnType<typeof createCapabilities> extends AllCapabilities
  ? true
  : never;
const _check: _VerifyImpl = true;
