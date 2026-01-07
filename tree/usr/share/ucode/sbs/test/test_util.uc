#!/usr/bin/env ucode

"use strict";

import * as fs from "fs";
import { srand } from "math";

import { test } from "./unit.uc";
import {
  normalize_domain,
  normalize_ether,
  normalize_ip,
  normalize_nft_comment,
  normalize_nft_timeout,
  quote_shell,
  rand_string,
  rand_temp_suffix,
  replace_file,
  run
} from "../util.uc";

test("normalize_domain", (expect) => {
  expect(normalize_domain()).toBe(null);
  expect(normalize_domain("foobar")).toBe("foobar");
  expect(normalize_domain(".1.com.-")).toBe("1.com");
  expect(normalize_domain("foo.#.bar")).toBe(null);
});

test("normalize_ether", (expect) => {
  expect(normalize_ether("foobar")).toBe(null);
  expect(normalize_ether("1:2:3:4:5:6")).toBe("01:02:03:04:05:06");
  expect(normalize_ether("  fe-DC-bA - 9 : 9 : 9   ")).toBe(
    "fe:dc:ba:09:09:09"
  );
  expect(normalize_ether("  fe-DC-bA2 - 9 : 9 : 9   ")).toBe(null);
  expect(normalize_ether("2001:db8::ff00:42:8329")).toBe(null);
  expect(normalize_ether("1:2:3::5:6")).toBe(null);
});

test("normalize_ip", (expect) => {
  expect(normalize_ip("foobar")).toBe(null);
  expect(normalize_ip("127 . 0 . 0 . 1")).toBe(null);
  expect(normalize_ip("127.0.0.1")).toBe("127.0.0.1");
  expect(normalize_ip("2001:db8::ff00:42:8329")).toBe("2001:db8::ff00:42:8329");
  expect(normalize_ip("0001:0000:0000:0000:0001:0000:0000:0000")).toBe(
    "1::1:0:0:0"
  );
});

test("normalize_nft_comment", (expect) => {
  expect(normalize_nft_comment(null)).toBe("");
  expect(normalize_nft_comment(" foo $ bar ")).toBe("foo $ bar");
  expect(normalize_nft_comment(" \x01 abc \x05 ")).toBe("abc");
  expect(
    normalize_nft_comment(
      "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    )
  ).toBe(
    "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
  );
});

test("normalize_nft_timeout", (expect) => {
  expect(normalize_nft_timeout(null)).toBe(1);
  expect(normalize_nft_timeout(-5)).toBe(1);
  expect(normalize_nft_timeout(23)).toBe(23);
  expect(normalize_nft_timeout(999999999999999)).toBe(86399);
});

test("quote_shell", (expect) => {
  expect(quote_shell(null)).toBe("''");
  expect(quote_shell("")).toBe("''");
  expect(quote_shell(42)).toBe("'42'");
  expect(quote_shell(" he\tllo there ")).toBe("' he\tllo there '");
  expect(quote_shell("evil\x00string")).toBe("'evil'");
  for (let c in split('\\$"`😊', "")) {
    expect(quote_shell(`a${c}'b`)).toBe(`'a${c}'"'"'b'`);
  }
});

test("rand_string", (expect) => {
  expect(length(rand_string())).toBe(1);
  expect(length(rand_string(0))).toBe(1);
  expect(length(rand_string(1))).toBe(1);
  expect(length(rand_string(20))).toBe(20);
});

test("rand_temp_suffix", (expect) => {
  expect(rand_temp_suffix()).toBe("");
  expect(rand_temp_suffix(0)).toBe("");
  expect(length(rand_temp_suffix(1))).toBe(1);
  expect(length(rand_temp_suffix(2))).toBe(2);
  expect(length(rand_temp_suffix(3))).toBe(3);
  expect(length(rand_temp_suffix(7))).toBe(7);
});

test("replace_file", (expect) => {
  const foobar_path = "/tmp/foobar.x4jn1ncj";
  const foobar_exists = !!fs.access(foobar_path, "f");
  expect(foobar_exists).toBe(false);
  if (foobar_exists == true) {
    print("BAIL");
    return;
  }
  const foobar = fs.open(foobar_path, "w");
  foobar.write("ok");
  foobar.close();
  let result = replace_file(foobar_path, "abc");
  expect(result.error).toBe(null);
  expect(fs.readfile(foobar_path)).toBe("abc");
  expect(fs.stat(foobar_path).mode).toBe(0o644);
  result = replace_file(
    foobar_path,
    (file, path) => {
      expect(substr(path, 0, length(foobar_path))).toBe(foobar_path);
      expect(file.write("1234")).toBe(4);
    },
    0o610
  );
  expect(fs.readfile(foobar_path)).toBe("1234");
  expect(fs.stat(foobar_path).mode).toBe(0o610);
  fs.unlink(foobar_path);
});

test("run", (expect) => {
  expect(run("echo hi")).toEquals({
    args: "echo hi",
    output: "hi\n",
    returncode: 0
  });
  expect(run(["echo", "a", "b"])).toEquals({
    args: ["echo", "a", "b"],
    output: "a b\n",
    returncode: 0
  });
  expect(run(["false"])).toEquals({
    args: ["false"],
    output: "",
    returncode: 1
  });
});
