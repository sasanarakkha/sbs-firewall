const apiURL = "../cgi-bin/sbs/tickets";
const successURL = "https://duckduckgo.com/";

const form = document.querySelector("form");
const addr = document.querySelector("input[name=addr]");
const duration = document.querySelector("select[name=duration]");
const comment = document.querySelector("input[name=comment]");
const submit = document.querySelector("input[type=submit]");

const dialogSuccess = document.querySelector("dialog.success");
const dialogError = document.querySelector("dialog.error");

const tableBody = document.querySelector("table tbody");

// We're okay with false positive...we let the backend verify it.
const matchIPv4 = /^([0-9]+\.){3}[0-9]+$/;
const matchIPv6 = /^([0-9a-f]+::?){1,7}[0-9a-f]+$/i;
const matchEther = /^([0-9a-f]+[-:]){5}[0-9a-f]+$/i;

function request(method, url, data, callback) {
  const xhr = new XMLHttpRequest();
  xhr.open(method, url);
  xhr.setRequestHeader("Content-Type", "application/json; charset=UTF-8");
  xhr.onreadystatechange = function () {
    if (this.readyState == 4) {
      let response;
      if (this.responseText) {
        try {
          response = JSON.parse(this.responseText);
        } catch (error) {
          response = { error: "invalid response: " + String(error) };
        }
      } else {
        response = { error: "no response" };
      }
      callback(response);
    }
  };
  if (data) {
    xhr.send(data);
  } else {
    xhr.send();
  }
}

function e(str) {
  return new Option(str).innerHTML;
}

function minutes(seconds) {
  let result = "";
  if (seconds >= 60) {
    result += Math.floor((seconds + 5) / 60) + " minute(s)";
  } else {
    result += seconds + " second(s)";
  }
  return result;
}

function handleFormResponse(data) {
  let dialog, message;
  if (data.error) {
    dialog = dialogError;
    message = data.error;
  } else {
    dialog = dialogSuccess;
    message = "Ethernet (MAC) address: " + data.ticket.ether;
  }
  dialog.querySelector("p").innerText = message;
  dialog.querySelector("button").addEventListener("click", (event) => {
    event.preventDefault();
    if (data.error) {
      dialog.removeAttribute("open");
      submit.removeAttribute("disabled");
    } else {
      form.reset();
      window.scrollTo(0, 0);
      window.location.reload();
    }
  });
  dialog.setAttribute("open", true);
}

addr.addEventListener("input", (event) => {
  const value = String(addr.value).trim();
  if (
    value != "" &&
    !matchIPv4.test(value) &&
    !matchIPv6.test(value) &&
    !matchEther.test(value)
  ) {
    addr.setCustomValidity("Please enter a valid IP or ethernet (MAC) address");
  } else {
    addr.setCustomValidity("");
  }
});

form.addEventListener("submit", function (event) {
  event.preventDefault();
  submit.setAttribute("disabled", true);
  const data = JSON.stringify({
    addr: String(addr.value),
    duration: parseInt(duration.value),
    comment: String(comment.value),
  });
  request("POST", apiURL, data, handleFormResponse);
});

function updateTicketsTable() {
  request("GET", apiURL, null, function (response) {
    console.log(response);
    let html = [];
    if (response.tickets && response.tickets.length) {
      for (const ticket of response.tickets) {
        html.push(
          "<tr><td>" +
            e(ticket.ether) +
            "</td><td>" +
            e(minutes(ticket.expires)) +
            "</td><td>" +
            e(ticket.comment) +
            "</td></tr>"
        );
      }
    } else {
      html.push('<tr><td colspan="3"><em>No tickets</em></td></tr>');
    }
    tableBody.innerHTML = html.join("");
    setTimeout(updateTicketsTable, 10000);
  });
}

updateTicketsTable();
