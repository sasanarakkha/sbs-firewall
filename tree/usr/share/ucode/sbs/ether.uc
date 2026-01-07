"use strict";

import * as socket from "socket";

import { LAN_INTERFACE } from "./_.uc";
import { normalize_ether, normalize_ip, run } from "./util.uc";

const QUERY_ETHER_ATTEMPTS = 5;
const QUERY_ETHER_SLEEP = 20; // milliseconds
const QUERY_ETHER_VALID_STATES = /REACHABLE|STALE|DELAY|PROBE/;

export const query_ether = (ip) => {
  const parsed_ip = normalize_ip(ip);
  if (!parsed_ip) {
    return { ip, error: `invalid ip: ${ip}` };
  }

  const result = { ip, parsed_ip },
    port = 9, // discard
    family = match(ip, /:/) ? socket.AF_INET6 : socket.AF_INET,
    socktype = socket.SOCK_DGRAM;

  for (let i = 0; i < QUERY_ETHER_ATTEMPTS; i++) {
    if (i > 0) {
      sleep(QUERY_ETHER_SLEEP);
    }
    const conn = socket.connect(ip, port, { family, socktype });
    if (conn) {
      conn.send("1");
      conn.close();
    }
    const run_result = run(["ip", "neigh", "show", ip, "dev", LAN_INTERFACE]);
    if (run_result.error) {
      result.error = run_result.error;
      continue;
    }

    const parts = split(trim(run_result.output), " ");
    if (match(uc(parts[-1]), QUERY_ETHER_VALID_STATES)) {
      const ether = normalize_ether(parts[2]);
      if (ether) {
        result.ether = ether;
        delete result.error;
        return result;
      } else {
        result.error = "unexpected output from ip neigh";
      }
    }
  }

  if (!result.error) {
    result.error = `ether not found for ip: ${ip}`;
  }
  return result;
};
