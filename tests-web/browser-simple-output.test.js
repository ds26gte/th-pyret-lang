const assert = require('assert');
const glob = require('glob');
const fs = require('fs');
const path = require('path');
const tester = require("./test-util.js");
const { fail } = require('assert');

const TEST_TIMEOUT = 20000;
const COMPILER_TIMEOUT = 10000; // ms, for each compiler run
const STARTUP_TIMEOUT = 6000;

describe("Testing browser simple-output programs", () => {

  jest.setTimeout(TEST_TIMEOUT);

  let setup;
  let driver;
  let baseURL;
  let refreshPagePerTest;

  beforeAll(async () => {
    setup = tester.setup();
    driver = setup.driver;
    baseURL = setup.baseURL;
    refreshPagePerTest = setup.refreshPagePerTest;

    if (refreshPagePerTest === false) {
      await driver.get(baseURL + "/page.html");
      await tester.pyretCompilerLoaded(driver, STARTUP_TIMEOUT);
    }
  });

  beforeEach(async () => {
    if (refreshPagePerTest === true) {
      await driver.get(baseURL + "/page.html");
    }
  });

  afterEach(async () => {
    if (refreshPagePerTest === false) {
      await tester.clearLogs(driver);
    }
  });

  afterAll(async () => {
    driver.quit();
  });

  describe("Basic page loads", function() {
    test("should load the webworker compiler", async function() {

      let loaded = await tester.pyretCompilerLoaded(driver, STARTUP_TIMEOUT);
      expect(loaded).toBeTruthy();

      // Testing program input works correctly
      let myValue = "FOO BAR";
      await tester.beginSetInputText(driver, myValue);

      let programInput = await driver.findElement({ id: "program" });
      let value = await programInput.getAttribute("value");

      expect(value).toEqual("FOO BAR");

    });
  });

  describe("Testing simple output", function() {
    const files = glob.sync("tests-new/simple-output/*.arr", {});

    // According to beforeEach(), webdriver reopens the editor
    // This clears the console and resets the compiler
    // Used for simplicity's sake and in the event of mutating tests with overlapping variables
    // NOTE(alex): Reloading before each test is necessary because I can't find a source guarenteeing
    //   test run order beyond using test sequencers. Otherwise, define basic page loads to go first
    //   and execute simple output tests.
    //   Maybe use test sequencers in the future?
    files.forEach(f => {
      test(`in-browser ${path.basename(f)} (${f})`, async function() {

        let typeCheck = f.match(/no-type-check/) === null;

        // Non-exact output check (scan):
        // Checks for any line beginning with prefix '###' and uses the trimmed content
        //   of the line after the prefix as expected search criteria in stdout
        let exact = f.match(/scan/) === null;

        if (refreshPagePerTest === true) {
          console.log("about to load");
          let loaded = await tester.pyretCompilerLoaded(driver, STARTUP_TIMEOUT);
          console.log("finished loading");
          expect(loaded).toBeTruthy();
        }

        const contents = String(fs.readFileSync(f));

        if (exact) {
          const firstLine = contents.split("\n")[0];
          const expectedOutput = firstLine.slice(firstLine.indexOf(" ")).trim();

          await tester.beginSetInputText(driver, contents)
            .then(tester.compileRun(driver, {
              'type-check': typeCheck,
              'stopify': false,
            }));

          // Does not work when in .then()
          if(firstLine.startsWith("###")) {
            let foundOutput =
              await tester.searchForRunningOutput(driver, expectedOutput, COMPILER_TIMEOUT);
            let runtimeErrors =
              await tester.areRuntimeErrors(driver);
            expect(foundOutput).toEqual(tester.OK);
            expect(runtimeErrors).toBeFalsy();
          }
          else if (firstLine.startsWith("##!")) {
            let foundOutput =
              await tester.searchForErrOutput(driver, expectedOutput, COMPILER_TIMEOUT);
            let runtimeErrors =
              await tester.areRuntimeErrors(driver);
            expect(foundOutput).toEqual(tester.OK);
            expect(runtimeErrors).toBeTruthy();
          }
          else {
            fail("Nothing to test");
          }

        } else {

          const lines = contents.split("\n");
          let expected = [];
          lines.forEach((line) => {
            if (line.startsWith("###") || line.startsWith("!##")) {
              const formatted = line.slice(line.indexOf(" ")).trim();
              expected.push(formatted);
            }
          });

          await tester.beginSetInputText(driver, contents)
            .then(tester.compileRun(driver, {
              'type-check': typeCheck,
              'stopify': false,
            }));

          for (let i = 0; i < expected.length; i++) {
            const expectedOutput = expected[i];
            let foundOutput =
              await tester.searchForRunningOutput(driver,
                expectedOutput, COMPILER_TIMEOUT);

              expect({ expectedOutput, result: foundOutput })
                .toEqual({ expectedOutput, result: tester.OK });
          }

          let runtimeErrors =
              await tester.areRuntimeErrors(driver);

          expect(runtimeErrors).toBeFalsy();

        }
      });
    });
  });
});
