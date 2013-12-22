var actuators, addActuator, addItem, addLogMessage, addRule, addSensor, addSwitch, addTemperature, removeRule, rules, sensors, socket, updateRule, updateSensorValue, voiceCallback;

actuators = [];

sensors = [];

rules = [];

socket = null;

$(document).on("pagecreate", '#index', function(event) {
  return $.get("/data.json", function(data) {
    var item, rule, _i, _j, _len, _len1, _ref, _ref1, _results;
    _ref = data.items;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      addItem(item);
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
  socket.on("sensor-value", function(data) {
    return updateSensorValue(data);
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
  socket.on("item-add", function(item) {
    return addItem(item);
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
  $('#index #rules').on("click", "#add-rule", function(event, ui) {
    $('#edit-rule-form').data('action', 'add');
    $('#edit-rule-text').val("");
    $('#edit-rule-id').val("");
    return true;
  });
  $("#items").sortable({
    items: "li.sortable",
    forcePlaceholderSize: true,
    placeholder: "sortable-placeholder",
    start: function(ev, ui) {
      $("#delete-item").show();
      $("#add-a-item").hide();
      $('#items').listview('refresh');
      return ui.item.css('border-bottom-width', '1px');
    },
    stop: function(ev, ui) {
      var item, order;
      $("#delete-item").hide();
      $("#add-a-item").show();
      $('#items').listview('refresh');
      ui.item.css('border-bottom-width', '0');
      order = (function() {
        var _i, _len, _ref, _results;
        _ref = $("#items li.sortable");
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          item = $(item);
          _results.push({
            type: item.data('item-type'),
            id: item.data('item-id')
          });
        }
        return _results;
      })();
      return $.post("update-order", {
        order: order
      });
    }
  }).disableSelection();
  return $("#delete-item").droppable({
    accept: "li.sortable",
    hoverClass: "ui-state-hover",
    drop: function(ev, ui) {
      var item;
      item = {
        id: ui.draggable.data('item-id'),
        type: ui.draggable.data('item-type')
      };
      $.post('remove-item', {
        item: item
      });
      if (item.type === 'actuator') {
        delete actuators[item.id];
      }
      if (item.type === 'sensor') {
        delete sensors[item.id];
      }
      return ui.draggable.remove();
    }
  });
});

addItem = function(item) {
  var li;
  li = (function() {
    if (item.template != null) {
      switch (item.template) {
        case "switch":
          return addSwitch(item);
        case "temperature":
          return addTemperature(item);
      }
    } else {
      switch (item.type) {
        case 'actuator':
          return addActuator(item);
        case 'sensor':
          return addSensor(item);
      }
    }
  })();
  li.data('item-type', item.type);
  return li.data('item-id', item.id);
};

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
  $('#add-a-item').before(li);
  $('#items').listview('refresh');
  return li;
};

addActuator = function(actuator) {
  var li;
  actuators[actuator.id] = actuator;
  li = $($('#actuator-template').html());
  li.find('label').text(actuator.name);
  if (actuator.error != null) {
    li.find('.error').text(actuator.error);
  }
  $('#add-a-item').before(li);
  $('#items').listview('refresh');
  return li;
};

addSensor = function(sensor) {
  var li;
  sensors[sensor.id] = sensor;
  li = $($('#actuator-template').html());
  li.find('label').text(sensor.name);
  if (sensor.error != null) {
    li.find('.error').text(sensor.error);
  }
  $('#add-a-item').before(li);
  $('#items').listview('refresh');
  return li;
};

addTemperature = function(sensor) {
  var li;
  sensors[sensor.id] = sensor;
  li = $($('#temperature-template').html());
  li.attr('id', "sensor-" + sensor.id);
  li.find('label').text(sensor.name);
  li.find('.temperature .val').text(sensor.values.temperature);
  li.find('.humidity .val').text(sensor.values.humidity);
  $('#add-a-item').before(li);
  $('#items').listview('refresh');
  return li;
};

updateSensorValue = function(sensorValue) {
  var li;
  li = $("\#sensor-" + sensorValue.id);
  return li.find("." + sensorValue.name + " .val").text(sensorValue.value);
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

$(document).on("pageinit", '#add-item', function(event) {
  $('#actuator-items').on("click", 'li', function() {
    var actuatorId, li;
    li = $(this);
    if (li.hasClass('added')) {
      return;
    }
    actuatorId = li.data('actuator-id');
    return $.get("/add-actuator/" + actuatorId, function(data) {
      li.data('icon', 'check');
      li.addClass('added');
      return li.buttonMarkup({
        icon: "check"
      });
    });
  });
  return $('#sensor-items').on("click", 'li', function() {
    var li, sensorId;
    li = $(this);
    if (li.hasClass('added')) {
      return;
    }
    sensorId = li.data('sensor-id');
    return $.get("/add-sensor/" + sensorId, function(data) {
      li.data('icon', 'check');
      li.addClass('added');
      return li.buttonMarkup({
        icon: "check"
      });
    });
  });
});

$(document).on("pagebeforeshow", '#add-item', function(event) {
  $.get("/api/list/actuators", function(data) {
    var a, li, _i, _len, _ref;
    console.log(actuators);
    $('#actuator-items').empty();
    _ref = data.actuators;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      a = _ref[_i];
      li = $($('#item-add-template').html());
      if (actuators[a.id] != null) {
        li.data('icon', 'check');
        li.addClass('added');
      }
      li.find('label').text(a.name);
      li.data('actuator-id', a.id);
      $('#actuator-items').append(li);
    }
    return $('#actuator-items').listview('refresh');
  });
  return $.get("/api/list/sensors", function(data) {
    var li, s, _i, _len, _ref;
    $('#sensor-items').empty();
    console.log(sensors);
    _ref = data.sensors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      s = _ref[_i];
      li = $($('#item-add-template').html());
      if (sensors[s.id] != null) {
        li.data('icon', 'check');
        li.addClass('added');
      }
      li.find('label').text(s.name);
      li.data('sensor-id', s.id);
      $('#sensor-items').append(li);
    }
    return $('#sensor-items').listview('refresh');
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

addLogMessage = function(entry) {
  var li;
  li = $($('#log-message-template').html());
  li.find('.level').text(entry.level).addClass(entry.level);
  li.find('.msg').text(entry.msg);
  $('#log-messages').append(li);
  return $('#log-messages').listview('refresh');
};

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
