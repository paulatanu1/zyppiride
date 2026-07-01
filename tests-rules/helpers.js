const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const PROJECT_ID = "zyppiride-test";
const RULES_PATH = path.resolve(__dirname, "..", "firestore.rules");

let testEnv;

async function getEnv() {
  if (!testEnv) {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {rules: fs.readFileSync(RULES_PATH, "utf8")},
    });
  }
  return testEnv;
}

async function tearDown() {
  if (testEnv) {
    await testEnv.cleanup();
    testEnv = null;
  }
}

/**
 * Seed a document bypassing security rules. Use for arranging the "before"
 * state of a test (e.g. preexisting user document).
 */
async function seed(docPath, data) {
  const env = await getEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(data);
  });
}

/** Firestore client authed as the given uid. */
async function asUser(uid) {
  const env = await getEnv();
  return env.authenticatedContext(uid).firestore();
}

module.exports = {getEnv, tearDown, seed, asUser, assertSucceeds, assertFails};
