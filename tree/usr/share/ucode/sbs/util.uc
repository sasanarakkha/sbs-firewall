"use strict";

import * as fs from "fs";
import { isnan, rand } from "math";
import { pack } from "struct";

export const NFT_COMMENT_MAX_LENGTH = 255;
export const NFT_MIN_TIMEOUT = 1; // 1 second
export const NFT_MAX_TIMEOUT = 60 * 60 * 24 - 1; // 24 hours - 1 second

export const normalize_domain = (domain) => {
  domain = trim(lc(domain || ""));
  if (match(domain, /^[a-z0-9.-]+$/)) {
    domain = trim(replace(domain, /\.+/g, "."), ".-");
    return domain || null;
  } else {
    return null;
  }
};

export const normalize_ether = (ether) => {
  const parts = split(replace(trim(ether), /[^-a-fA-F0-9:]/g, ""), /:|-/);
  if (length(parts) == 6) {
    const octets = [];
    for (let part in parts) {
      const octet = hex(part);
      if (octet == null || isnan(octet) || octet < 0 || octet > 255) {
        return null;
      } else {
        push(octets, octet);
      }
    }
    return join(
      ":",
      map(octets, (p) => sprintf("%02x", p))
    );
  } else {
    return;
    null;
  }
};

export const normalize_ip = (ip) => {
  const arr = iptoarr(trim(ip));
  if (type(arr) == "array") {
    return arrtoip(arr);
  } else {
    return null;
  }
};

export const normalize_nft_comment = (comment) => {
  return substr(
    trim(replace(replace(trim(`${comment || ""}`), /[^ -~]/g, ""), '"', "'")),
    0,
    NFT_COMMENT_MAX_LENGTH
  );
};
export const normalize_nft_timeout = (timeout) => {
  return max(NFT_MIN_TIMEOUT, min(NFT_MAX_TIMEOUT, int(timeout) || 0));
};

export const quote_shell = (str) => {
  str = `${str ?? ""}`;
  if (str == "") {
    return "''";
  } else {
    return "'" + replace(str, "'", "'\"'\"'") + "'";
  }
};

export const rand_string = (n) => {
  n = max(1, int(n) || 0);
  while (true) {
    const result = fs.open("/dev/urandom").read(n);
    if (type(result) == "string" && length(result) >= n) {
      return substr(result, 0, n);
    }
  }
};

export const rand_temp_suffix = (n) => {
  return substr(hexenc(rand_string((n + 1) / 2)), 0, n);
};

export const replace_file = (path, content, mode) => {
  const tmp_path = `${path}.${rand_temp_suffix(10)}`,
    tmp = fs.open(tmp_path, "wx", 0o600);
  let error;
  if (!tmp) {
    error = fs.error();
  } else {
    if (type(content) == "function") {
      content(tmp, tmp_path);
    } else {
      if (tmp.write(content) == null) {
        error = tmp.error();
      }
    }
    if (error) {
      //
    } else if (!tmp.close()) {
      error = tmp.error();
    } else if (!fs.chmod(tmp_path, mode || 0o644)) {
      error = fs.error();
    } else if (!fs.rename(tmp_path, path)) {
      error = fs.error();
    } else {
      return {};
    }
  }
  if (!error) {
    error = "unknown error";
  }
  if (tmp) {
    fs.unlink(tmp_path);
  }
  return { error };
};

export const run = (args, handler) => {
  const result = { args };
  let cmd;
  if (type(args) == "array") {
    cmd = join(" ", map(args, quote_shell));
  } else {
    cmd = `${args}`;
  }

  const proc = fs.popen(cmd);
  if (!proc) {
    result.error = fs.error() || "Unknown error";
    return result;
  }

  if (handler) {
    try {
      result.output = handler(proc);
    } catch (error) {
      result.error = error;
    }
  } else {
    result.output = proc.read("all");
    if (result.output == null) {
      const proc_error = proc.error();
      if (proc_error) {
        result.error = proc_error;
      } else {
        // Even if proc.read("all") returns null, we're okay.
      }
    }
  }
  result.output ??= "";

  result.returncode = proc.close();
  if (result.returncode == null) {
    result.error = proc.error() || "Unknown error";
  }
  return result;
};

export const mktemp = () => {
  const run_result = run("mktemp"),
    path = trim(run_result.output);
  if (path) {
    const file = fs.open(path, "w");
    if (file) {
      return { path, file };
    } else {
      const result = { error: fs.error() || "unknown error" };
      return result;
    }
  } else {
    return { error: run_result.error || "unknown error" };
  }
};

export const run_nft = (cmd) => {
  const result = run(["nft", "--json", cmd], json);
  if (!result.error && result.returncode != 0) {
    result.error = `unexpected returncode: ${result.returncode}`;
  }
  return result;
};
