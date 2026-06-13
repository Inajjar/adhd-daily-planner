"use strict";

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {createJsonResponse} = require("../openai/client");
const {
  prioritySuggestionsPrompt,
  overwhelmPrompt,
  microStepsPrompt,
  dailyPlanPrompt,
  reschedulePrompt,
  smartRemindersPrompt,
} = require("../openai/prompts");
const {parseJson, assertString, assertArray} = require("../openai/validation");

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const DEFAULT_MODEL = "gpt-5-mini";

function createCallable(handler) {
  return onCall(
    {
      region: "us-central1",
      cors: true,
      secrets: [OPENAI_API_KEY],
    },
    async (request) => {
      if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "Authentication required.");
      }

      const apiKey = OPENAI_API_KEY.value();
      if (!apiKey) {
        throw new HttpsError("failed-precondition", "OPENAI_API_KEY missing.");
      }

      try {
        return await handler(request.data || {}, apiKey);
      } catch (error) {
        console.error("Premium AI callable failed", error);
        throw new HttpsError("internal", error.message || "AI request failed.");
      }
    },
  );
}

exports.generatePrioritySuggestions = createCallable(async (data, apiKey) => {
  assertString(data.brainDump, "brainDump");
  const prompt = prioritySuggestionsPrompt(data.brainDump);
  const text = await createJsonResponse({
    apiKey,
    model: data.model || DEFAULT_MODEL,
    systemPrompt: prompt.systemPrompt,
    userPrompt: prompt.userPrompt,
  });
  return parseJson(text);
});

exports.detectOverwhelm = createCallable(async (data, apiKey) => {
  assertArray(data.tasks, "tasks");
  const prompt = overwhelmPrompt(data.tasks);
  const text = await createJsonResponse({
    apiKey,
    model: data.model || DEFAULT_MODEL,
    systemPrompt: prompt.systemPrompt,
    userPrompt: prompt.userPrompt,
  });
  return parseJson(text);
});

exports.generateMicroSteps = createCallable(async (data, apiKey) => {
  assertString(data.taskTitle, "taskTitle");
  const prompt = microStepsPrompt(data.taskTitle);
  const text = await createJsonResponse({
    apiKey,
    model: data.model || DEFAULT_MODEL,
    systemPrompt: prompt.systemPrompt,
    userPrompt: prompt.userPrompt,
  });
  return parseJson(text);
});

exports.generateDailyPlan = createCallable(async (data, apiKey) => {
  assertArray(data.tasks, "tasks");
  const prompt = dailyPlanPrompt(data.tasks, data.currentEnergy || "medium");
  const text = await createJsonResponse({
    apiKey,
    model: data.model || DEFAULT_MODEL,
    systemPrompt: prompt.systemPrompt,
    userPrompt: prompt.userPrompt,
  });
  return parseJson(text);
});

exports.rescheduleTasks = createCallable(async (data, apiKey) => {
  assertArray(data.tasks, "tasks");
  const prompt = reschedulePrompt(data.tasks);
  const text = await createJsonResponse({
    apiKey,
    model: data.model || DEFAULT_MODEL,
    systemPrompt: prompt.systemPrompt,
    userPrompt: prompt.userPrompt,
  });
  return parseJson(text);
});

exports.generateSmartReminders = createCallable(async (data, apiKey) => {
  assertArray(data.tasks, "tasks");
  const prompt = smartRemindersPrompt(
    data.tasks,
    data.currentEnergy || "medium",
    data.streak || 0,
  );
  const text = await createJsonResponse({
    apiKey,
    model: data.model || DEFAULT_MODEL,
    systemPrompt: prompt.systemPrompt,
    userPrompt: prompt.userPrompt,
  });
  return parseJson(text);
});
