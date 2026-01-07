"use strict";

import * as fs from "fs";
import * as log from "log";
import * as socket from "socket";

import { CONFIG_REMOTE_ALLOWLIST_DOMAIN, get_config } from "./config.uc";

const LOOP_DOMAIN_COUNT = 5;
const LOOP_TIMEOUT = 1000; // ms

const debug = (message) => {
  log.ulog(log.LOG_DEBUG, message + "\n");
};

const info = (message) => {
  log.ulog(log.LOG_INFO, message + "\n");
};

const query_ip = (domain, family) => {
  return filter(
    map(
      socket.addrinfo(domain, 80, { family, socktype: socket.SOCK_STREAM }),
      (r) => r?.addr?.address
    ) || [],
    (ip) => ip
  );
};

const query_ipv4 = (domain) => {
  return query_ip(domain, socket.AF_INET);
};

const query_ipv6 = (domain) => {
  return query_ip(domain, socket.AF_INET6);
};

let __domains = [];
const get_domains = (n) => {
  if (length(__domains) == 0) {
    const config_result = get_config(CONFIG_REMOTE_ALLOWLIST_DOMAIN);
    if (!config_result.error) {
      __domains = config_result.domains;
    }
  }
  const result = [];
  for (let i = 0; i < n && length(__domains) > 0; i++) {
    push(result, shift(__domains));
  }
  return result;
};

export const poll_domains = (request) => {
  const log_level = lc(trim(`${request?.args?.log_level}`));
  if (log_level == "debug") {
    log.ulog_open(
      log.ULOG_SYSLOG | log.ULOG_STDIO,
      log.LOG_DAEMON,
      "poll_domains"
    );
    log.ulog_threshold(log.LOG_DEBUG);
  } else {
    log.ulog_open(log.ULOG_SYSLOG, log.LOG_DAEMON, "poll_domains");
    log.ulog_threshold(log.LOG_INFO);
  }

  signal("SIGTERM", () => {
    info("exiting...");
    exit(0);
  });

  info("starting...");

  while (true) {
    const domains = get_domains(LOOP_DOMAIN_COUNT);
    for (let domain in domains) {
      const ipv4 = query_ipv4(domain);
      debug(`${domain}: ${ipv4}`);
      const ipv6 = query_ipv6(domain);
      debug(`${domain}: ${ipv6}`);
    }
    sleep(LOOP_TIMEOUT);
  }
};

export default poll_domains;
