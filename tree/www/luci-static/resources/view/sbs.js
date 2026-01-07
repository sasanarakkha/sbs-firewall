"use strict";
"require view";
"require fs";
"require rpc";
"require ui";

var CONFIGS = {
  local_allowlist_ether: {
    name: "local_allowlist_ether",
    title: "Local Allowlist",
    description: [
      "Devices with these ethernet (MAC) addresses will always be allowed access.",
      "This list has lower presidence than the Local Blocklist.",
    ],
  },
  local_blocklist_ether: {
    name: "local_blocklist_ether",
    title: "Local Blocklist",
    description: [
      "Devices with these ethernet (MAC) addresses will always be blocked from access.",
      "This list has the highest presidence, overriding all other lists.",
    ],
  },
  remote_allowlist_domain: {
    name: "remote_allowlist_domain",
    title: "Remote Allowlist",
    description: [
      "Devices not specified in the Local Blocklist and Local Allowlist will have access to these domains.",
    ],
  },
};

var callAddTicket = rpc.declare({
  object: "sbs",
  method: "add_ticket",
  params: ["addr", "duration", "comment"],
});

var callDeleteTicket = rpc.declare({
  object: "sbs",
  method: "delete_ticket",
  params: ["addr"],
});

var callGetNftSets = rpc.declare({ object: "sbs", method: "get_nft_sets" });

var callGetTickets = rpc.declare({ object: "sbs", method: "get_tickets" });

var callProcessConfig = rpc.declare({
  object: "sbs",
  method: "process_config",
  params: ["name"],
});

function getConfigPath(name) {
  return "/etc/sbs/" + name + ".conf";
}

function getConfig(name) {
  return L.resolveDefault(fs.read(getConfigPath(name)), "");
}

function setConfig(name, content) {
  return fs.write(getConfigPath(name), content);
}

var isReadonlyView = !L.hasViewPermission() || null;

return view.extend({
  handleReset: null,
  handleSave: null,
  handleSaveApply: null,

  handleSaveConfig: function (name, event) {
    var selector = "textarea[name=" + name + "]";
    var value = document.querySelector(selector).value || "";
    value = value.trim().replace(/\r\n/g, "\n") + "\n";
    return setConfig(name, value)
      .then(function () {
        callProcessConfig(name)
          .then(function () {
            document.querySelector(selector).value = value;
            ui.addNotification(
              null,
              E("p", _("Contents have been saved.")),
              "info"
            );
          })
          .catch(function (e) {
            ui.addNotification(
              null,
              E("p", "Could not process config: %s".format(e.message))
            );
          });
      })
      .catch(function (e) {
        ui.addNotification(
          null,
          E("p", _("Unable to save contents: %s").format(e.message))
        );
      });
  },

  load: function () {
    return Promise.all([
      callGetTickets(),
      getConfig("local_allowlist_ether"),
      getConfig("local_blocklist_ether"),
      getConfig("remote_allowlist_domain"),
      callGetNftSets(),
    ]);
  },

  render: function (data) {
    var view = E("div", {}, [
      E("h2", "SBS Firewall"),
      E("div", {}, [
        this.renderTicketsTab(data[0]),
        this.renderEditConfigTab(CONFIGS.local_blocklist_ether, data[2]),
        this.renderEditConfigTab(CONFIGS.local_allowlist_ether, data[1]),
        this.renderEditConfigTab(CONFIGS.remote_allowlist_domain, data[3]),
        this.renderStatusTab(data[4]),
      ]),
    ]);
    ui.tabs.initTabGroup(view.lastElementChild.childNodes);
    return view;
  },

  renderEditConfigTab: function (config, content) {
    var textAreaOptions = {
      name: config.name,
      style: "width: 100%",
      rows: 15,
      disabled: isReadonlyView,
    };
    var actionsOptions = {
      class: "cbi-page-actions",
    };
    var buttonOptions = {
      class: "btn cbi-button-save",
      click: ui.createHandlerFn(this, "handleSaveConfig", config.name),
      disabled: isReadonlyView,
    };
    return E(
      "div",
      {
        "data-tab": config.name,
        "data-tab-title": config.title,
      },
      [
        E("h3", {}, config.title),
        config.description.map(function (text) {
          return E("p", {}, text);
        }),
        E("p", {}, "Text following '#' and the '#' are ignored."),
        E("p", {}, E("textarea", textAreaOptions, content)),
        E("div", actionsOptions, E("button", buttonOptions, _("Save"))),
      ].flat()
    );
  },

  renderStatusTab: function (data) {
    var sets = data.sets;

    function renderNftElement(el) {
      var parts = [el.val];
      if (el.timeout) parts.push("timeout: " + el.timeout);
      if (el.expires) parts.push("expires: " + el.expires);
      if (el.comment) parts.push("comment: " + el.comment);
      return E("code", {}, parts.join(", "));
    }

    function renderNftSet(set) {
      return E("div", {}, [
        E("h4", {}, E("code", {}, set.name)),
        E(
          "p",
          {},
          set.elements
            .map(function (el) {
              return [renderNftElement(el), ", "];
            })
            .flat()
        ),
      ]);
    }

    return E(
      "div",
      { "data-tab": "status", "data-tab-title": _("Status") },
      [
        E("h3", {}, _("nftables (Firewall) Sets")),
        sets.map(renderNftSet),
      ].flat()
    );
  },

  reloadTicketsTable: function () {
    return callGetTickets().then(
      L.bind(function (data) {
        this.updateTicketsTable(".table", data.tickets);
      }, this)
    );
  },

  clickDeleteTicket: function (ether, event) {
    return callDeleteTicket(ether).then(
      L.bind(function (data) {
        if (!data.error) {
          ui.addNotification(null, E("p", "Ticket was deleted."), "info");
          return this.reloadTicketsTable();
        } else {
          ui.addNotification(
            null,
            E(
              "p",
              "Error deleting ticket: %s".format(data.error || "Unknown error")
            ),
            "info"
          );
        }
      }, this)
    );
  },

  clickAddTicket: function (event) {
    var addrEl = document.querySelector("input[name=addr]"),
      durationEl = document.querySelector("input[name=duration]"),
      commentEl = document.querySelector("input[name=comment]");
    var addr = String(addrEl.value),
      duration = parseInt(durationEl.value) || 0,
      comment = String(commentEl.value);
    return callAddTicket(addr, duration, comment).then(
      L.bind(function (data) {
        if (data.ticket && !data.error) {
          addrEl.value = "";
          durationEl.value = "";
          commentEl.value = "";
          var buttonEl = document.querySelector(".cbi-button");
          delete buttonEl.disable;
          buttonEl.className = "cbi-button cbi-button-add";
          ui.addNotification(null, E("p", "Ticket was added."), "info");
          return this.reloadTicketsTable();
        } else {
          ui.addNotification(
            null,
            E(
              "p",
              "Error adding ticket: %s".format(data.error || "Unknown error")
            )
          );
        }
      }, this)
    );
  },

  renderTicketsTab: function (data) {
    var tickets = data.tickets;
    var clickAddTicket = ui.createHandlerFn(this, this.clickAddTicket);
    var view = E(
      "div",
      {
        "data-tab": "tickets",
        "data-tab-title": "Tickets",
      },
      [
        E("h3", "Tickets"),
        E("div", { class: "add-item" }, [
          E("input", {
            class: "cbi-input-text",
            type: "text",
            name: "addr",
            placeholder: "IP or ethernet address",
            keydown: function (ev) {
              if (ev.keyCode === 13) clickAddTicket(ev);
            },
            disabled: isReadonlyView,
          }),
          E("input", {
            class: "cbi-input-text",
            type: "text",
            name: "duration",
            placeholder: "Duration (sec)",
            keydown: function (ev) {
              if (ev.keyCode === 13) clickAddTicket(ev);
            },
            disabled: isReadonlyView,
          }),
          E("input", {
            class: "cbi-input-text",
            type: "text",
            name: "comment",
            placeholder: "Comment",
            keydown: function (ev) {
              if (ev.keyCode === 13) clickAddTicket(ev);
            },
            disabled: isReadonlyView,
          }),
          E(
            "button",
            {
              class: "cbi-button cbi-button-add",
              click: clickAddTicket,
              disabled: isReadonlyView,
            },
            "Add Ticket"
          ),
        ]),
        E("p", {}, ""),
        E("table", { class: "table" }, [
          E("tr", { class: "tr table-titles" }, [
            E("th", { class: "th" }, "Ethernet (MAC) address"),
            E("th", { class: "th" }, "Timeout"),
            E("th", { class: "th" }, "Expires"),
            E("th", { class: "th" }, "Comment"),
            E("th", { class: "th center nowrap cbi-section-actions" }),
          ]),
        ]),
      ]
    );
    this.updateTicketsTable(view.lastElementChild, tickets);
    return view;
  },

  updateTicketsTable: function (table, tickets) {
    var rows = tickets.map(function (ticket) {
      return [
        ticket.ether,
        ticket.timeout,
        ticket.expires,
        ticket.comment,
        E(
          "button",
          {
            class: "btn cbi-button-action",
            click: ui.createHandlerFn(
              this,
              this.clickDeleteTicket,
              ticket.ether
            ),
          },
          _("Delete")
        ),
      ];
    }, this);
    cbi_update_table(table, rows, E("em", "No tickets"));
  },
});
