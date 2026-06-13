"use strict";

const OpenAI = require("openai");

function buildOpenAiClient(apiKey) {
  return new OpenAI({
    apiKey,
  });
}

async function createJsonResponse({
  apiKey,
  model,
  systemPrompt,
  userPrompt,
}) {
  const client = buildOpenAiClient(apiKey);
  const response = await client.responses.create({
    model,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text:
              `${systemPrompt}\nReturn JSON only. Do not wrap it in markdown.`,
          },
        ],
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: userPrompt,
          },
        ],
      },
    ],
  });

  return response.output_text;
}

module.exports = {
  createJsonResponse,
};
