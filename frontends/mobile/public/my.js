var voiceCallback;

$(document).on("pageinit", function(a) {
  var socket;
  if (typeof device !== "undefined" && device !== null) {
    $("#talk").show().bind("vclick", function(event, ui) {
      return device.startVoiceRecognition("voiceCallback");
    });
  }
  $(".switch").bind("change", function(event, ui) {
    var actuatorAction, actuatorID;
    console.log(event);
    console.log(ui);
    actuatorID = $(this).data("actuator-id");
    actuatorAction = $(this).val();
    return $.get("/api/actuator/" + actuatorID + "/" + actuatorAction, function(data) {
      return typeof device !== "undefined" && device !== null ? device.showToast("fertig") : void 0;
    });
  });
  socket = io.connect("/");
  return socket.on("switch-status", function(data) {
    var value;
    if (data.state != null) {
      value = (data.state ? "turnOn" : "turnOff");
      return $("#flip-" + data.id).val(value).slider('refresh');
    }
  });
});

$.ajaxSetup({
  timeout: 7000
});

$(document).ajaxStart(function() {
  return $.mobile.loading("show", {
    text: "Lade...",
    textVisible: true,
    textonly: false
  });
});

$(document).ajaxStop(function() {
  return $.mobile.loading("hide");
});

$(document).ajaxError(function(event, jqxhr, settings, exception) {
  var error;
  error = void 0;
  if (exception) {
    error = "Fehler: " + exception;
  } else {
    error = "Ein Fehler ist aufgetreten.";
  }
  return alert(error);
});

voiceCallback = function(matches) {
  return $.get("/api/speak", {
    word: matches
  }, function(data) {
    device.showToast(data);
    return $("#talk").blur();
  });
};
