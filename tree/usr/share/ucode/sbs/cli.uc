"use strict";

import rpc from "./rpc.uc";
import poll_domains from "./poll_domains.uc";

const commands = {
  ...rpc,
  poll_domains: {
    args: { log_level: "info or debug" },
    call: poll_domains
  }
};

const usage = (command) => {
  const arg_names = map(keys(commands[command].args), uc);
  print(`Usage: sbs ${command} ${join(" ", arg_names)}\n`);
};

export const main = (argv) => {
  if (length(argv) == 0 || match(argv[0], /^(help|-h|--help)$/)) {
    for (let command in keys(commands)) {
      usage(command);
    }
    return 1;
  }

  const command = argv[0],
    args = slice(argv, 1),
    spec = commands[command];

  if (!spec) {
    print(`sbs: no such command: ${command}\n`);
    return 2;
  }

  if (length(args) != length(keys(spec.args))) {
    usage(command);
    return 2;
  }

  const request = { args: {} };
  for (let arg_name in keys(spec.args)) {
    request.args[arg_name] = shift(args);
  }

  const result = spec.call(request);
  printf("%.2J\n", result);
  if (result.error) {
    return 255;
  } else {
    return 0;
  }
};
