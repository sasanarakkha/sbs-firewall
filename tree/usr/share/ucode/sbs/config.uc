"use strict";

import * as fs from "fs";

import { SBS_PREFIX } from "./_.uc";
import { NFT_FAMILY, NFT_TABLE } from "./nft.uc";
import { normalize_domain, normalize_ether, replace_file } from "./util.uc";

export const CONFIG_DIR = `/etc/${SBS_PREFIX}`;
export const CONFIG_LOCAL_BLOCKLIST_ETHER = "local_blocklist_ether";
export const CONFIG_LOCAL_ALLOWLIST_ETHER = "local_allowlist_ether";
export const CONFIG_REMOTE_ALLOWLIST_DOMAIN = "remote_allowlist_domain";
export const CONFIG_NAMES = [
  CONFIG_LOCAL_BLOCKLIST_ETHER,
  CONFIG_LOCAL_ALLOWLIST_ETHER,
  CONFIG_REMOTE_ALLOWLIST_DOMAIN
];
export const NFT_RULESET_POST_DIR = "/usr/share/nftables.d/ruleset-post";
export const DNSMASQ_NFTSETS_PATH = `/etc/dnsmasq.d/${SBS_PREFIX}_nftsets.conf`;

export const parse_config_tokens = (content, normalizer) => {
  content = replace(content || "", /[^\n -~]/g, " ");
  content = replace(content, /#[^\n]*(\n|$)/g, " ");
  content = replace(content, /[ \n]+/g, " ");
  content = lc(trim(content));
  const tokens = filter(map(split(content, " "), normalizer), (s) => s);
  return uniq(sort(tokens));
};

const write_automatic_warning = (file) => {
  file.write("# Automatically generated. DO NOT EDIT!\n\n");
};

const write_nft_header = (file) => {
  file.write("#!/usr/sbin/nft -f\n");
  write_automatic_warning(file);
};

const write_add_nft_set = (file, nft_set_name, nft_set_type, tokens) => {
  file.write(`table ${NFT_FAMILY} ${NFT_TABLE} {\n`);
  file.write(`  set ${nft_set_name} {\n`);
  file.write(`    type ${nft_set_type}\n`);
  file.write("    flags dynamic,timeout\n");
  if (type(tokens) == "array" && length(tokens) > 0) {
    file.write("    elements = { ");
    file.write(join(",", tokens));
    file.write(" }\n");
  }
  file.write("  }\n}\n");
};

const write_flush_nft_set = (file, nft_set_name) => {
  file.write(`flush set inet fw4 ${nft_set_name}\n`);
};

export const get_config = (name) => {
  const result = { name };
  let normalizer;
  if (
    name == CONFIG_LOCAL_BLOCKLIST_ETHER ||
    name == CONFIG_LOCAL_ALLOWLIST_ETHER
  ) {
    result.type = "ether";
    normalizer = normalize_ether;
  } else if (name == CONFIG_REMOTE_ALLOWLIST_DOMAIN) {
    result.type = "domain";
    normalizer = normalize_domain;
  } else {
    return { ...result, error: `unknown config: ${name}` };
  }

  const config_path = `${CONFIG_DIR}/${name}.conf`,
    config_content = fs.readfile(config_path) || "",
    tokens = parse_config_tokens(config_content, normalizer);

  if (result.type == "ether") {
    return { ...result, ethers: tokens };
  } else {
    return { ...result, domains: tokens };
  }
};

export const get_config_names = () => {
  return { names: CONFIG_NAMES };
};

export const get_configs = () => {
  return { configs: map(CONFIG_NAMES, get_config) };
};

export const process_config = (name) => {
  const result = get_config(name);
  if (result.error) {
    return result;
  }

  let nft_set_name;
  if (result.type == "ether") {
    nft_set_name = `${SBS_PREFIX}_${name}`;
  } else {
    nft_set_name = `${SBS_PREFIX}_${replace(name, /_domain$/, "")}`;
  }

  const nft_set_path = `${NFT_RULESET_POST_DIR}/${SBS_PREFIX}_${name}.nft`;
  const nft_set_result = replace_file(
    nft_set_path,
    (file) => {
      write_nft_header(file);
      if (result.type == "ether") {
        write_add_nft_set(file, nft_set_name, "ether_addr");
        write_flush_nft_set(file, nft_set_name);
        write_add_nft_set(file, nft_set_name, "ether_addr", result.ethers);
      } else {
        write_add_nft_set(file, `${nft_set_name}_ipv4`, "ipv4_addr");
        write_flush_nft_set(file, `${nft_set_name}_ipv4`);
        write_add_nft_set(file, `${nft_set_name}_ipv6`, "ipv6_addr");
        write_flush_nft_set(file, `${nft_set_name}_ipv6`);
      }
    },
    0o644
  );

  if (nft_set_result.error) {
    return { ...nft_set_result, ...result };
  }

  if (result.type == "domain") {
    const nft_dnsmasq_config_result = replace_file(
      DNSMASQ_NFTSETS_PATH,
      (file) => {
        write_automatic_warning(file);
        for (let domain in result.domains) {
          file.write(`nftset=/${domain}/`);
          file.write(`4#${NFT_FAMILY}#${NFT_TABLE}#${nft_set_name}_ipv4,`);
          file.write(`6#${NFT_FAMILY}#${NFT_TABLE}#${nft_set_name}_ipv6\n`);
        }
      },
      0o644
    );
    if (nft_dnsmasq_config_result.error) {
      return { ...nft_dnsmasq_config_result, ...result };
    }
  }

  let returncode;

  returncode = system(["nft", "-f", nft_set_path]);
  if (returncode != 0) {
    return { ...result, error: `nft exited ${returncode}` };
  }

  returncode = system(["/etc/init.d/dnsmasq", "restart"]);
  if (returncode != 0) {
    return { ...result, error: `dnsmasq restart exited ${returncode}` };
  }

  return result;
};

export const process_configs = () => {
  return { configs: map(CONFIG_NAMES, process_config) };
};
