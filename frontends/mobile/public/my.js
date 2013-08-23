var voiceCallback;

$(document).on("pageinit", function(a) {
  if (typeof device !== "undefined" && device !== null) {
    $("#talk").show().bind("vclick", function(event, ui) {
      return device.startVoiceRecognition("voiceCallback");
    });
  }
  return $(".switch").each(function(i, o) {
    var _this = this;
    return $(o).bind("vclick", function(event, ui) {
      var actuatorAction, actuatorID;
      actuatorID = $(o).data("actuator-id");
      actuatorAction = $(o).data("actuator-action");
      return $.get("/api/actuator/" + actuatorID + "/" + actuatorAction, function(data) {
        return typeof device !== "undefined" && device !== null ? device.showToast("fertig") : void 0;
      });
    });
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
