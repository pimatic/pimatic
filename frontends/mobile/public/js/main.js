var addRule, addSwitch, voiceCallback;

$(document).on("pagecreate", function(event) {
  return $.get("/data.json", function(data) {
    var actuator, rule, _i, _j, _len, _len1, _ref, _ref1, _results;
    _ref = data.actuators;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      actuator = _ref[_i];
      addSwitch(actuator);
    }
    _ref1 = data.rules;
    _results = [];
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      rule = _ref1[_j];
      _results.push(addRule(rule));
    }
    return _results;
  });
});

$(document).on("pageinit", function(event) {
  var socket;
  if (typeof device !== "undefined" && device !== null) {
    $("#talk").show().bind("vclick", function(event, ui) {
      return device.startVoiceRecognition("voiceCallback");
    });
  }
  socket = io.connect("/");
  return socket.on("switch-status", function(data) {
    var value;
    if (data.state != null) {
      value = (data.state ? "on" : "off");
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

addSwitch = function(actuator) {
  var li, select, val;
  li = $($('#switch-template').html());
  li.find('label').attr('for', "flip-" + actuator.id).text(actuator.name);
  select = li.find('select').attr('name', "flip-" + actuator.id).attr('id', "flip-" + actuator.id).data('actuator-id', actuator.id);
  if (actuator.state != null) {
    val = actuator.state ? 'on' : 'off';
    select.find("option[value=" + val + "]").attr('selected', 'selected');
  }
  select.slider().bind("change", function(event, ui) {
    var actuatorAction;
    actuatorAction = $(this).val() === 'on' ? 'turnOn' : 'turnOff';
    return $.get("/api/actuator/" + actuator.id + "/" + actuatorAction, function(data) {
      return typeof device !== "undefined" && device !== null ? device.showToast("fertig") : void 0;
    });
  });
  $('#actuators').append(li);
  return $('#actuators').listview('refresh');
};

addRule = function(rule) {
  var li;
  li = $($('#rule-template').html());
  li.attr('id', "rule-" + rule.id);
  li.find('.condition').text(rule.condition);
  li.find('.action').text(rule.action);
  $('#rules').append(li);
  return $('#rules').listview('refresh');
};

voiceCallback = function(matches) {
  return $.get("/api/speak", {
    word: matches
  }, function(data) {
    device.showToast(data);
    return $("#talk").blur();
  });
};
