"use strict";

import { traceback } from "debug";

export const test = (name, block) => {
  print(`${name}: `);
  const fail_log = [];
  const check = (result, expected) => {
    if (result === expected) {
      print(".");
    } else {
      print("F");
      push(fail_log, { result, expected, stacktrace: traceback(3)[0] });
    }
  };
  block((result) => ({
    toBe: (expected) => {
      check(result, expected);
    },
    toEquals: (expected) => {
      check(`${result}`, `${expected}`);
    }
  }));
  print("\n");
  if (length(fail_log) > 0) {
    print(`  ${length(fail_log)} failures:\n`);
    for (let log in fail_log) {
      print(`    ${[log.result]} != ${[log.expected]}\n`);
      print(
        `    file: ${log.stacktrace.filename}, line: ${log.stacktrace.line}\n`
      );
      print("--------------------------------------------------------------\n");
      print(log.stacktrace.context);
      print("--------------------------------------------------------------\n");
    }
  }
};
