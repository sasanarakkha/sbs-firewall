#!/usr/bin/env ucode

"use strict";

import { test } from "./unit.uc";
import { parse_config_tokens } from "../config.uc";

test("parse_config_tokens", (expect) => {
  expect(parse_config_tokens("", uc)).toEquals([]);
  expect(
    parse_config_tokens(
      `# 1:2:3:4:5:6
>>> ff:ff:ff:ff:ff:ff foo.bar <<<
9-8-7-f-e-d
4-5-6\x01-4-5-6
fred # 1:2:3:4:5:6`,
      (x) => (length(x) > 10 ? uc(x) : null)
    )
  ).toEquals(["9-8-7-F-E-D", "FF:FF:FF:FF:FF:FF"]);
});
