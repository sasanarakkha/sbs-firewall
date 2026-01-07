"use strict";

import * as socket from "socket";

import { NFT_FAMILY, NFT_TABLE, NFT_TICKETS_ETHER_SET } from "./nft.uc";
import { query_ether } from "./ether.uc";
import { get_nft_set } from "./nft.uc";
import {
  normalize_ether,
  normalize_ip,
  normalize_nft_comment,
  normalize_nft_timeout,
  run_nft
} from "./util.uc";

const NFT_TICKETS_ETHER_SET_PATH = `${NFT_FAMILY} ${NFT_TABLE} ${NFT_TICKETS_ETHER_SET}`;

const parse_and_query_addr = (addr, callback) => {
  let parsed_addr;
  const ether = normalize_ether(addr);
  if (ether) {
    parsed_addr = { addr, type: "ether", ether };
  } else {
    const ip = normalize_ip(addr);
    if (ip) {
      parsed_addr = {
        addr,
        type: match(ip, /:/) ? "ipv6" : "ipv4",
        ip: ip
      };
      const query_ether_result = query_ether(ip);
      if (query_ether_result.error) {
        return { parsed_addr: parsed_addr, error: query_ether_result.error };
      } else {
        parsed_addr.ether = query_ether_result.ether;
      }
    } else {
      return { error: `invalid addr: ${addr}` };
    }
  }
  return { parsed_addr: parsed_addr, ...callback(parsed_addr) };
};

export const get_tickets = () => {
  const nft_set = get_nft_set(NFT_TICKETS_ETHER_SET);
  if (nft_set.error) {
    return { error: nft_set.error };
  } else if (type(nft_set.elements) != "array") {
    return { error: "unexpected elements" };
  } else {
    return {
      tickets: map(nft_set.elements, function (el) {
        return {
          ether: el.val,
          timeout: el.timeout,
          expires: el.expires,
          comment: el.comment
        };
      })
    };
  }
};

const _get_ticket = (parsed_addr) => {
  // Unfortunately nft get in OpenWRT 24.10 doesn't provide JSON output,
  // so we need to scan all the tickets.
  const tickets = get_tickets();
  if (tickets.error) {
    return { error: tickets.error };
  }
  for (let ticket in tickets.tickets) {
    if (normalize_ether(ticket.ether) == parsed_addr.ether) {
      return { ticket };
    }
  }
  return { error: `ticket not found for ether: ${parsed_addr.ether}` };
};

const _set_ticket = (parsed_addr, timeout, expires, comment) => {
  timeout = normalize_nft_timeout(timeout);
  expires = normalize_nft_timeout(expires);
  if (expires > timeout) {
    expires = timeout;
  }
  const pre_comment =
    parsed_addr.type == "ether"
      ? `ether=${parsed_addr.ether}`
      : `ip=${parsed_addr.ip}`;
  comment = trim(normalize_nft_comment(pre_comment + ` ${comment || ""}`));
  const run_nft_result = run_nft(
    `destroy element ${NFT_TICKETS_ETHER_SET_PATH} { ${parsed_addr.ether} };` +
      `add element ${NFT_TICKETS_ETHER_SET_PATH} { ${parsed_addr.ether} ` +
      `timeout ${timeout}s ` +
      `expires ${expires}s ` +
      `comment "${comment}" ` +
      "};"
  );
  if (run_nft_result.error) {
    return { error: run_nft_result.error };
  } else {
    return { ticket: { ether: parsed_addr.ether, timeout, expires, comment } };
  }
};

export const add_ticket = (addr, duration, comment) => {
  return parse_and_query_addr(addr, (parsed_addr) => {
    let timeout = normalize_nft_timeout(duration),
      expires = timeout;
    const ticket_result = _get_ticket(parsed_addr);
    if (ticket_result.ticket) {
      timeout += ticket_result.ticket.timeout;
      expires += ticket_result.ticket.expires;
    }
    return _set_ticket(parsed_addr, timeout, expires, comment);
  });
};

export const delete_ticket = (addr) => {
  return parse_and_query_addr(addr, (parsed_addr) => {
    const destroy_result = run_nft(
      `destroy element ${NFT_TICKETS_ETHER_SET_PATH} { ${parsed_addr.ether} };`
    );
    if (destroy_result.error) {
      return { error: destroy_result.error };
    } else {
      return {};
    }
  });
};

export const get_ticket = (addr) => {
  return parse_and_query_addr(addr, _get_ticket);
};

export const replace_ticket = (addr, timeout, expires, comment) => {
  return parse_and_query_addr(addr, (parsed_addr) => {
    return _set_ticket(parsed_addr, timeout, expires, comment);
  });
};
