"use strict";

const {initializeApp} = require("firebase-admin/app");

initializeApp();

exports.generatePrioritySuggestions =
  require("./src/callables/premiumAi").generatePrioritySuggestions;
exports.detectOverwhelm =
  require("./src/callables/premiumAi").detectOverwhelm;
exports.generateMicroSteps =
  require("./src/callables/premiumAi").generateMicroSteps;
exports.generateDailyPlan =
  require("./src/callables/premiumAi").generateDailyPlan;
exports.rescheduleTasks =
  require("./src/callables/premiumAi").rescheduleTasks;
exports.generateSmartReminders =
  require("./src/callables/premiumAi").generateSmartReminders;
