"use strict";

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    const cleaned = text
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/, "");
    return JSON.parse(cleaned);
  }
}

function assertString(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Invalid or missing string field: ${field}`);
  }
}

function assertArray(value, field) {
  if (!Array.isArray(value)) {
    throw new Error(`Invalid or missing array field: ${field}`);
  }
}

module.exports = {
  parseJson,
  assertString,
  assertArray,
};
