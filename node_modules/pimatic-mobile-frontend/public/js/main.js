var actuators, addActuator, addLogMessage, addRule, addSwitch, removeRule, rules, socket, updateRule, voiceCallback;

actuators = [];

rules = [];

socket = null;

$(document).on("pagecreate", '#index', function(event) {
  return $.get("/data.json", function(data) {
    var item, rule, _i, _j, _len, _len1, _ref, _ref1, _results;
    _ref = data.items;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      if (item.template != null) {
        if (item.template === "switch") {
          addSwitch(item);
        } else {
          addActuator(item);
        }
      } else {
        addActuator(item);
      }
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

$(document).on("pageinit", '#index', function(event) {
  if (typeof device !== "undefined" && device !== null) {
    $("#talk").show().bind("vclick", function(event, ui) {
      return device.startVoiceRecognition("voiceCallback");
    });
  }
  socket = io.connect("/");
  socket.on("switch-status", function(data) {
    var value;
    if (data.state != null) {
      value = (data.state ? "on" : "off");
      return $("#flip-" + data.id).val(value).slider('refresh');
    }
  });
  socket.on("rule-add", function(rule) {
    return addRule(rule);
  });
  socket.on("rule-update", function(rule) {
    return updateRule(rule);
  });
  socket.on("rule-remove", function(rule) {
    return removeRule(rule);
  });
  socket.on('log', function(entry) {
    return console.log(entry);
  });
  $('#index #items').on("change", ".switch", function(event, ui) {
    var actuatorAction, actuatorId;
    actuatorId = $(this).data('actuator-id');
    actuatorAction = $(this).val() === 'on' ? 'turnOn' : 'turnOff';
    return $.get("/api/actuator/" + actuatorId + "/" + actuatorAction, function(data) {
      return typeof device !== "undefined" && device !== null ? device.showToast("fertig") : void 0;
    });
  });
  $('#index #rules').on("click", ".rule", function(event, ui) {
    var rule, ruleId;
    ruleId = $(this).data('rule-id');
    rule = rules[ruleId];
    $('#edit-rule-form').data('action', 'update');
    $('#edit-rule-text').val("if " + rule.condition + " then " + rule.action);
    $('#edit-rule-id').val(ruleId);
    return true;
  });
  return $('#index #rules').on("click", "#add-rule", function(event, ui) {
    $('#edit-rule-form').data('action', 'add');
    $('#edit-rule-text').val("");
    $('#edit-rule-id').val("");
    return true;
  });
});

$(document).on("pageinit", '#edit-rule', function(event) {
  $('#edit-rule').on("submit", '#edit-rule-form', function() {
    var action, ruleId, ruleText;
    ruleId = $('#edit-rule-id').val();
    ruleText = $('#edit-rule-text').val();
    action = $('#edit-rule-form').data('action');
    $.post("/api/rule/" + ruleId + "/" + action, {
      rule: ruleText
    }, function(data) {
      if (data.success) {
        return $.mobile.changePage('#index', {
          transition: 'slide',
          reverse: true
        });
      } else {
        return alert(data.error);
      }
    });
    return false;
  });
  $('#edit-rule').on("click", '#edit-rule-remove', function() {
    var ruleId;
    ruleId = $('#edit-rule-id').val();
    $.get("/api/rule/" + ruleId + "/remove", function(data) {
      if (data.success) {
        return $.mobile.changePage('#index', {
          transition: 'slide',
          reverse: true
        });
      } else {
        return alert(data.error);
      }
    });
    return false;
  });
  return $(document).on("pagebeforeshow", '#edit-rule', function(event) {
    var action;
    action = $('#edit-rule-form').data('action');
    switch (action) {
      case 'add':
        $('#edit-rule h3.add').show();
        $('#edit-rule h3.edit').hide();
        $('#edit-rule-id').textinput('enable');
        return $('#edit-rule-advanced').hide();
      case 'update':
        $('#edit-rule h3.add').hide();
        $('#edit-rule h3.edit').show();
        $('#edit-rule-id').textinput('disable');
        return $('#edit-rule-advanced').show();
    }
  });
});

$(document).on("pageinit", '#log', function(event) {
  return $.get("/api/messages", function(data) {
    var entry, _i, _len;
    for (_i = 0, _len = data.length; _i < _len; _i++) {
      entry = data[_i];
      addLogMessage(entry);
    }
    return socket.on('log', function(entry) {
      return addLogMessage(entry);
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

addSwitch = function(actuator) {
  var li, select, val;
  actuators[actuator.id] = actuator;
  li = $($('#switch-template').html());
  li.find('label').attr('for', "flip-" + actuator.id).text(actuator.name);
  select = li.find('select').attr('name', "flip-" + actuator.id).attr('id', "flip-" + actuator.id).data('actuator-id', actuator.id);
  if (actuator.state != null) {
    val = actuator.state ? 'on' : 'off';
    select.find("option[value=" + val + "]").attr('selected', 'selected');
  }
  select.slider();
  $('#items').append(li);
  return $('#items').listview('refresh');
};

addActuator = function(actuator) {
  var li;
  actuators[actuator.id] = actuator;
  li = $($('#actuator-template').html());
  li.find('label').text(actuator.name);
  if (actuator.error != null) {
    li.find('.error').text(actuator.error);
  }
  $('#items').append(li);
  return $('#items').listview('refresh');
};

addRule = function(rule) {
  var li;
  rules[rule.id] = rule;
  li = $($('#rule-template').html());
  li.attr('id', "rule-" + rule.id);
  li.find('a').data('rule-id', rule.id);
  li.find('.condition').text(rule.condition);
  li.find('.action').text(rule.action);
  $('#add-rule').before(li);
  return $('#rules').listview('refresh');
};

updateRule = function(rule) {
  var li;
  rules[rule.id] = rule;
  li = $("\#rule-" + rule.id);
  li.find('.condition').text(rule.condition);
  li.find('.action').text(rule.action);
  return $('#rules').listview('refresh');
};

removeRule = function(rule) {
  delete rules[rule.id];
  $("\#rule-" + rule.id).remove();
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

addLogMessage = function(entry) {
  var li;
  li = $($('#log-message-template').html());
  li.find('.level').text(entry.level).addClass(entry.level);
  li.find('.msg').text(entry.msg);
  $('#log-messages').append(li);
  return $('#log-messages').listview('refresh');
};
