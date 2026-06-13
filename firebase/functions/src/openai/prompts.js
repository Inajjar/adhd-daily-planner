"use strict";

const baseRules = [
  "You are an ADHD-friendly planning assistant.",
  "Keep outputs practical, calm, and specific.",
  "Prefer short tasks and low-friction first steps.",
  "Never include extra commentary outside JSON.",
].join(" ");

function prioritySuggestionsPrompt(brainDump) {
  return {
    systemPrompt: `${baseRules} Classify tasks into high, medium, and low priority. Estimate minutes and energy level as low, medium, or high.`,
    userPrompt: [
      "Analyze this brain dump and return JSON with this shape:",
      "{",
      '  "tasks": [{"title": string, "priority": "high|medium|low", "duration_minutes": number, "energy": "low|medium|high", "reason": string}],',
      '  "start_with": string,',
      '  "suggestion": string',
      "}",
      "",
      "Brain dump:",
      brainDump,
    ].join("\n"),
  };
}

function overwhelmPrompt(tasks) {
  return {
    systemPrompt: `${baseRules} Pick the single most manageable task when the user feels overwhelmed.`,
    userPrompt: [
      "Return JSON with this shape:",
      "{",
      '  "chosen_task_id": string,',
      '  "chosen_task_title": string,',
      '  "estimated_minutes": number,',
      '  "energy": "low|medium|high",',
      '  "why_this_task": string,',
      '  "first_micro_step": string',
      "}",
      "",
      "Tasks:",
      JSON.stringify(tasks),
    ].join("\n"),
  };
}

function microStepsPrompt(taskTitle) {
  return {
    systemPrompt: `${baseRules} Break large tasks into small concrete steps. The first step must be tiny.`,
    userPrompt: [
      "Return JSON with this shape:",
      "{",
      '  "task_title": string,',
      '  "tiny_first_step": string,',
      '  "steps": [string]',
      "}",
      "",
      `Task: ${taskTitle}`,
    ].join("\n"),
  };
}

function dailyPlanPrompt(tasks, currentEnergy) {
  return {
    systemPrompt: `${baseRules} Choose the best daily focus list for an ADHD user. Hide the rest for now.`,
    userPrompt: [
      "Return JSON with this shape:",
      "{",
      '  "today_focus_ids": [string],',
      '  "today_focus_titles": [string],',
      '  "why": string,',
      '  "hidden_count": number',
      "}",
      "",
      `Current energy: ${currentEnergy}`,
      `Tasks: ${JSON.stringify(tasks)}`,
    ].join("\n"),
  };
}

function reschedulePrompt(tasks) {
  return {
    systemPrompt: `${baseRules} Reorder incomplete tasks for tomorrow. Remove clearly obsolete tasks only if the reason is explicit.`,
    userPrompt: [
      "Return JSON with this shape:",
      "{",
      '  "tomorrow": [{"id": string, "title": string, "priority_reason": string}],',
      '  "dropped_task_ids": [string]',
      "}",
      "",
      `Incomplete tasks: ${JSON.stringify(tasks)}`,
    ].join("\n"),
  };
}

function smartRemindersPrompt(tasks, currentEnergy, streak) {
  return {
    systemPrompt: `${baseRules} Write short contextual reminders that reduce friction and encourage immediate action.`,
    userPrompt: [
      "Return JSON with this shape:",
      "{",
      '  "reminders": [{"title": string, "message": string, "action_label": string}]',
      "}",
      "",
      `Current energy: ${currentEnergy}`,
      `Current streak: ${streak}`,
      `Tasks: ${JSON.stringify(tasks)}`,
    ].join("\n"),
  };
}

module.exports = {
  prioritySuggestionsPrompt,
  overwhelmPrompt,
  microStepsPrompt,
  dailyPlanPrompt,
  reschedulePrompt,
  smartRemindersPrompt,
};
