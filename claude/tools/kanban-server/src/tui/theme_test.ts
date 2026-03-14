// src/tui/theme_test.ts
import { assertEquals, assertMatch } from "@std/assert";
import { priorityIcon, statusColor, statusIcon, theme } from "./theme.ts";

Deno.test("theme has all required color keys", () => {
  const required = [
    "bg",
    "surface",
    "surfaceHover",
    "text",
    "textMuted",
    "textDim",
    "amber",
    "sage",
    "coral",
    "sky",
    "violet",
    "rose",
    "border",
    "borderActive",
  ];
  for (const key of required) {
    assertEquals(
      typeof (theme as Record<string, string>)[key],
      "string",
      `missing: ${key}`,
    );
  }
});

Deno.test("theme colors are valid hex", () => {
  for (const [key, value] of Object.entries(theme)) {
    assertMatch(
      value as string,
      /^#[0-9A-Fa-f]{6}$/,
      `invalid hex for ${key}: ${value}`,
    );
  }
});

Deno.test("statusColor returns correct color for each status", () => {
  assertEquals(statusColor("in_progress"), theme.amber);
  assertEquals(statusColor("todo"), theme.sky);
  assertEquals(statusColor("done"), theme.sage);
  assertEquals(statusColor("review"), theme.violet);
  assertEquals(statusColor("backlog"), theme.textMuted);
});

Deno.test("priorityIcon returns icon with correct format", () => {
  assertEquals(priorityIcon("high"), "●");
  assertEquals(priorityIcon("medium"), "◐");
  assertEquals(priorityIcon("low"), "○");
});

Deno.test("statusIcon returns icon for each status", () => {
  assertEquals(statusIcon("in_progress"), "▶");
  assertEquals(statusIcon("todo"), "○");
  assertEquals(statusIcon("done"), "✓");
  assertEquals(statusIcon("review"), "◎");
  assertEquals(statusIcon("backlog"), "◆");
});
