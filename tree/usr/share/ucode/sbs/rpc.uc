"use strict";

import {
  get_config,
  get_config_names,
  get_configs,
  process_config,
  process_configs
} from "./config.uc";
import { get_nft_set, get_nft_set_names, get_nft_sets } from "./nft.uc";
import { query_ether } from "./ether.uc";
import {
  add_ticket,
  delete_ticket,
  get_ticket,
  get_tickets,
  replace_ticket
} from "./ticket.uc";

export const rpc = {
  get_config: {
    args: { name: "name" },
    call: (r) => get_config(r.args.name)
  },
  get_config_names: {
    args: {},
    call: () => get_config_names()
  },
  get_configs: {
    args: {},
    call: () => get_configs()
  },
  process_config: {
    args: { name: "name" },
    call: (r) => process_config(r.args.name)
  },
  process_configs: {
    args: {},
    call: () => process_configs()
  },

  get_nft_set: {
    args: { name: "name" },
    call: (r) => get_nft_set(r.args.name)
  },
  get_nft_set_names: {
    args: {},
    call: () => get_nft_set_names()
  },
  get_nft_sets: {
    args: {},
    call: () => get_nft_sets()
  },

  query_ether: {
    args: { ip: "ipv4 or ipv6" },
    call: (r) => query_ether(r.args.ip)
  },

  add_ticket: {
    args: { addr: "ip or ether", duration: 3600, comment: "ok" },
    call: (r) => add_ticket(r.args.addr, r.args.duration, r.args.comment)
  },
  delete_ticket: {
    args: { addr: "ip or ether" },
    call: (r) => delete_ticket(r.args.addr)
  },
  get_ticket: {
    args: { addr: "ip or ether" },
    call: (r) => get_ticket(r.args.addr)
  },
  get_tickets: {
    args: {},
    call: () => get_tickets()
  },
  replace_ticket: {
    args: {
      addr: "ip or ether",
      timeout: 3600,
      expires: 1800,
      comment: "ok"
    },
    call: (r) =>
      replace_ticket(
        r.args.addr,
        r.args.timeout,
        r.args.expires,
        r.args.comment
      )
  }
};

export default rpc;
