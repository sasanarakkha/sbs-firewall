"use strict";

import { SBS_PREFIX } from "./_.uc";
import { run_nft } from "./util.uc";

export const NFT_FAMILY = "inet";
export const NFT_TABLE = "fw4";

export const NFT_LOCAL_BLOCKLIST_ETHER_SET = `${SBS_PREFIX}_local_blocklist_ether`;
export const NFT_LOCAL_ALLOWLIST_ETHER_SET = `${SBS_PREFIX}_local_allowlist_ether`;
export const NFT_TICKETS_ETHER_SET = `${SBS_PREFIX}_tickets_ether`;
export const NFT_REMOTE_ALLOWLIST_IPV4_SET = `${SBS_PREFIX}_remote_allowlist_ipv4`;
export const NFT_REMOTE_ALLOWLIST_IPV6_SET = `${SBS_PREFIX}_remote_allowlist_ipv6`;

export const NFT_SET_NAMES = [
  NFT_LOCAL_BLOCKLIST_ETHER_SET,
  NFT_LOCAL_ALLOWLIST_ETHER_SET,
  NFT_TICKETS_ETHER_SET,
  NFT_REMOTE_ALLOWLIST_IPV4_SET,
  NFT_REMOTE_ALLOWLIST_IPV6_SET
];

const normalize_nft_set_element = (el) => {
  let result;
  if (type(el) == "string") {
    el = { val: el };
  } else {
    el = el?.elem;
  }
  if (type(el?.val) == "string") {
    const result = { val: el.val };
    if (el.timeout) result.timeout = el.timeout;
    if (el.expires) result.expires = el.expires;
    if (el.comment) result.comment = el.comment;
    return result;
  } else {
    return null;
  }
};

export const get_nft_set = (name) => {
  const result = { name };
  if (!(name in NFT_SET_NAMES)) {
    return { ...result, error: `unknown set: ${name}` };
  }
  const run_nft_result = run_nft(
    `list set ${NFT_FAMILY} ${NFT_TABLE} ${name};`
  );
  if (run_nft_result.error) {
    return { ...run_nft_result, ...result };
  }
  const set = run_nft_result.output?.nftables?.[1]?.set;
  if (type(set) != "object") {
    return { ...run_nft_result, ...result, error: "unexpected output" };
  }
  let elements = type(set.elem) == "array" ? set.elem : [];
  elements = filter(map(elements, normalize_nft_set_element), (el) => el);
  return { ...result, elements };
};

export const get_nft_set_names = () => {
  return { names: NFT_SET_NAMES };
};

export const get_nft_sets = () => {
  return { sets: map(NFT_SET_NAMES, get_nft_set) };
};
