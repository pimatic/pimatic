var actuators, addBrowsePlugin, addItem, addLogMessage, addPlugin, addRule, ajaxAlertFail, ajaxShowToast, buildActuator, buildPresents, buildSensor, buildSwitch, buildTemperature, errorCount, loadData, removeRule, rules, sensors, showToast, socket, uncheckAllPlugins, updateErrorCount, updateRule, updateSensorValue, voiceCallback, __,
  __slice = [].slice;

actuators = [];

sensors = [];

rules = [];

errorCount = 0;

socket = null;

$(document).on("pagecreate", '#index', function(event) {
  return loadData();
});

$(document).on("pageinit", '#index', function(event) {
  var onConnectionError;
  if (typeof device !== "undefined" && device !== null) {
    $("#talk").show().bind("vclick", function(event, ui) {
      return device.startVoiceRecognition("voiceCallback");
    });
  }
  socket = io.connect("/", {
    'connect timeout': 5000,
    'reconnection delay': 500,
    'reconnection limit': 2000,
    'max reconnection attempts': Infinity
  });
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
    if (entry.level === 'error') {
      errorCount++;
      updateErrorCount();
    }
    showToast(entry.msg);
    return console.log(entry);
  });
  socket.on('reconnect', function() {
    $.mobile.loading("hide");
    return loadData();
  });
  socket.on('disconnect', function() {
    return $.mobile.loading("show", {
      text: __("connection lost, retying") + '...',
      textVisible: true,
      textonly: false
    });
  });
  onConnectionError = function() {
    $.mobile.loading("show", {
      text: __("could not connect, retying") + '...',
      textVisible: true,
      textonly: false
    });
    return setTimeout(function() {
      return socket.socket.connect(function() {
        $.mobile.loading("hide");
        return loadData();
      });
    }, 2000);
  };
  socket.on('error', onConnectionError);
  socket.on('connect_error', onConnectionError);
  $('#index #items').on("change", ".switch", function(event, ui) {
    var actuatorAction, actuatorId;
    actuatorId = $(this).data('actuator-id');
    actuatorAction = $(this).val() === 'on' ? 'turnOn' : 'turnOff';
    return $.get("/api/actuator/" + actuatorId + "/" + actuatorAction).done(ajaxShowToast).fail(ajaxAlertFail);
  });
  $('#index #rules').on("click", ".rule", function(event, ui) {
    var rule, ruleId;
    ruleId = $(this).data('rule-id');
    rule = rules[ruleId];
    $('#edit-rule-form').data('action', 'update');
    $('#edit-rule-text').val("if " + rule.condition + " then " + rule.action);
    $('#edit-rule-id').val(ruleId);
    event.stopPropagation();
    return true;
  });
  $('#index #rules').on("click", "#add-rule", function(event, ui) {
    $('#edit-rule-form').data('action', 'add');
    $('#edit-rule-text').val("");
    $('#edit-rule-id').val("");
    event.stopPropagation();
    return true;
  });
  $("#items").sortable({
    items: "li.sortable",
    forcePlaceholderSize: true,
    placeholder: "sortable-placeholder",
    handle: ".handle",
    cursor: "move",
    revert: 100,
    scroll: true,
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
  });
  $("#items .handle").disableSelection();
  $("#delete-item").droppable({
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

loadData = function() {
  return $.get("/data.json").done(function(data) {
    var item, rule, _i, _j, _len, _len1, _ref, _ref1;
    actuators = [];
    sensors = [];
    rules = [];
    $('#items .item').remove();
    _ref = data.items;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      addItem(item);
    }
    $('#rules .rule').remove();
    _ref1 = data.rules;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      rule = _ref1[_j];
      addRule(rule);
    }
    errorCount = data.errorCount;
    return updateErrorCount();
  });
};

updateErrorCount = function() {
  var e;
  if ($('#error-count').find('.ui-btn-text').length > 0) {
    $('#error-count').find('.ui-btn-text').text(errorCount);
    try {
      $('#error-count').button('refresh');
    } catch (_error) {
      e = _error;
    }
  } else {
    $('#error-count').text(errorCount);
  }
  if (errorCount === 0) {
    return $('#error-count').hide();
  } else {
    return $('#error-count').show();
  }
};

addItem = function(item) {
  var li;
  li = (function() {
    if (item.template != null) {
      switch (item.template) {
        case "switch":
          return buildSwitch(item);
        case "temperature":
          return buildTemperature(item);
        case "presents":
          return buildPresents(item);
      }
    } else {
      switch (item.type) {
        case 'actuator':
          return buildActuator(item);
        case 'sensor':
          return buildSensor(item);
      }
    }
  })();
  li.data('item-type', item.type);
  li.data('item-id', item.id);
  li.addClass('item');
  $('#add-a-item').before(li);
  li.append($('<div class="ui-icon-alt handle">\
    <div class="ui-icon ui-icon-bars"></div>\
  </div>'));
  return $('#items').listview('refresh');
};

buildSwitch = function(actuator) {
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
  return li;
};

buildActuator = function(actuator) {
  var li;
  actuators[actuator.id] = actuator;
  li = $($('#actuator-template').html());
  li.find('label').text(actuator.name);
  if (actuator.error != null) {
    li.find('.error').text(actuator.error);
  }
  return li;
};

buildSensor = function(sensor) {
  var li;
  sensors[sensor.id] = sensor;
  li = $($('#actuator-template').html());
  li.find('label').text(sensor.name);
  if (sensor.error != null) {
    li.find('.error').text(sensor.error);
  }
  return li;
};

buildTemperature = function(sensor) {
  var li;
  sensors[sensor.id] = sensor;
  li = $($('#temperature-template').html());
  li.attr('id', "sensor-" + sensor.id);
  li.find('label').text(sensor.name);
  li.find('.temperature .val').text(sensor.values.temperature);
  li.find('.humidity .val').text(sensor.values.humidity);
  return li;
};

buildPresents = function(sensor) {
  var li;
  sensors[sensor.id] = sensor;
  li = $($('#presents-template').html());
  li.attr('id', "sensor-" + sensor.id);
  li.find('label').text(sensor.name);
  if (sensor.values.present === true) {
    li.find('.present .val').text('present').addClass('val-present');
  } else {
    li.find('.present .val').text('not present').addClass('val-not-present');
  }
  return li;
};

updateSensorValue = function(sensorValue) {
  var li;
  li = $("\#sensor-" + sensorValue.id);
  if (sensorValue.name === 'present') {
    if (sensorValue.value === true) {
      return li.find("." + sensorValue.name + " .val").text('present').addClass('val-present').removeClass('val-not-present');
    } else {
      return li.find("." + sensorValue.name + " .val").text('not present').addClass('val-not-resent').removeClass('val-present');
    }
  } else {
    return li.find("." + sensorValue.name + " .val").text(sensorValue.value);
  }
};

addRule = function(rule) {
  var li;
  rules[rule.id] = rule;
  li = $($('#rule-template').html());
  li.attr('id', "rule-" + rule.id);
  li.find('a').data('rule-id', rule.id);
  li.find('.condition').text(rule.condition);
  li.find('.action').text(rule.action);
  li.addClass('rule');
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
    return $.get("/add-actuator/" + actuatorId).done(function(data) {
      li.data('icon', 'check');
      li.addClass('added');
      return li.buttonMarkup({
        icon: "check"
      });
    }).fail(ajaxAlertFail);
  });
  return $('#sensor-items').on("click", 'li', function() {
    var li, sensorId;
    li = $(this);
    if (li.hasClass('added')) {
      return;
    }
    sensorId = li.data('sensor-id');
    return $.get("/add-sensor/" + sensorId).done(function(data) {}, li.data('icon', 'check'), li.addClass('added'), li.buttonMarkup({
      icon: "check"
    })).fail(ajaxAlertFail);
  });
});

$(document).on("pagebeforeshow", '#add-item', function(event) {
  $.get("/api/list/actuators").done(function(data) {
    var a, li, _i, _len, _ref;
    $('#actuator-items .item').remove();
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
      li.addClass('item');
      $('#actuator-items').append(li);
    }
    return $('#actuator-items').listview('refresh');
  }).fail(ajaxAlertFail);
  return $.get("/api/list/sensors").done(function(data) {
    var li, s, _i, _len, _ref;
    $('#sensor-items .item').remove();
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
      li.addClass('item');
      $('#sensor-items').append(li);
    }
    return $('#sensor-items').listview('refresh');
  }).fail(ajaxAlertFail);
});

$(document).on("pageinit", '#edit-rule', function(event) {
  $('#edit-rule').on("submit", '#edit-rule-form', function() {
    var action, ruleId, ruleText;
    ruleId = $('#edit-rule-id').val();
    ruleText = $('#edit-rule-text').val();
    action = $('#edit-rule-form').data('action');
    $.post("/api/rule/" + ruleId + "/" + action, {
      rule: ruleText
    }).done(function(data) {
      if (data.success) {
        return $.mobile.changePage('#index', {
          transition: 'slide',
          reverse: true
        });
      } else {
        return alert(data.error);
      }
    }).fail(ajaxAlertFail);
    return false;
  });
  $('#edit-rule').on("click", '#edit-rule-remove', function() {
    var ruleId;
    ruleId = $('#edit-rule-id').val();
    $.get("/api/rule/" + ruleId + "/remove").done(function(data) {
      if (data.success) {
        return $.mobile.changePage('#index', {
          transition: 'slide',
          reverse: true
        });
      } else {
        return alert(data.error);
      }
    }).fail(ajaxAlertFail);
    return false;
  });
  return $(document).on("pagebeforeshow", '#edit-rule', function(event) {
    var action;
    action = $('#edit-rule-form').data('action');
    switch (action) {
      case 'add':
        $('#edit-rule h3').text(__('Edit rule'));
        $('#edit-rule-id').textinput('enable');
        return $('#edit-rule-advanced').hide();
      case 'update':
        $('#edit-rule h3').text(__('Add new rule'));
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
  $.get("/api/messages").done(function(data) {
    var entry, _i, _len, _ref;
    _ref = data.messages;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      entry = _ref[_i];
      addLogMessage(entry);
    }
    $('#log-messages').listview('refresh');
    return socket.on('log', function(entry) {
      addLogMessage(entry);
      return $('#log-messages').listview('refresh');
    });
  }).fail(ajaxAlertFail);
  return $('#log').on("click", '#clear-log', function(event, ui) {
    return $.get("/clear-log").done(function() {
      return $('#log-messages').empty();
    }, $('#log-messages').listview('refresh'), errorCount = 0, updateErrorCount()).fail(ajaxAlertFail);
  });
});

addLogMessage = function(entry) {
  var li;
  li = $($('#log-message-template').html());
  li.find('.level').text(entry.level).addClass(entry.level);
  li.find('.msg').text(entry.msg);
  return $('#log-messages').append(li);
};

$(document).on("pageinit", '#plugins', function(event) {
  $.get("/api/plugins/installed").done(function(data) {
    var p, _i, _len, _ref;
    _ref = data.plugins;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      addPlugin(p);
    }
    $('#plugin-list').listview("refresh");
    return $("#plugin-list input[type='checkbox']").checkboxradio();
  }).fail(ajaxAlertFail);
  return $('#plugins').on("click", '#plugin-do-action', function(event, ui) {
    var ele, selected, val, _i, _len, _ref;
    val = $('#select-plugin-action').val();
    if (val === 'select') {
      return alert(__('Please select a action first'));
    }
    selected = [];
    _ref = $('#plugin-list input[type="checkbox"]');
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      ele = _ref[_i];
      ele = $(ele);
      if (ele.is(':checked')) {
        selected.push(ele.data('plugin-name'));
      }
    }
    return $.post("/api/plugins/" + val, {
      plugins: selected
    }).done(function(data) {
      var past;
      past = (val === 'add' ? 'added' : 'removed');
      showToast(data[past].length + __(" plugins " + past) + "." + (data[past].length > 0 ? " " + __("Please restart pimatic.") : ""));
      uncheckAllPlugins();
    }).fail(ajaxAlertFail);
  });
});

uncheckAllPlugins = function() {
  var ele, _i, _len, _ref, _results;
  _ref = $('#plugin-list input[type="checkbox"]');
  _results = [];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    ele = _ref[_i];
    _results.push($(ele).prop("checked", false).checkboxradio("refresh"));
  }
  return _results;
};

addPlugin = function(plugin) {
  var checkBoxId, id, li;
  id = "plugin-" + plugin.name;
  li = $($('#plugin-template').html());
  li.attr('id', id);
  checkBoxId = "cb-" + id;
  li.find('.name').text(plugin.name);
  li.find('.description').text(plugin.description);
  li.find('.version').text(plugin.version);
  li.find('.homepage').text(plugin.homepage).attr('href', plugin.homepage);
  li.find('.active').text(plugin.active ? __('activated') : __('deactived'));
  li.find("input[type='checkbox']").attr('id', checkBoxId).attr('name', checkBoxId).data('plugin-name', plugin.name);
  return $('#plugin-list').append(li);
};

$(document).on("pagebeforeshow", '#plugins', function(event) {
  return $('#select-plugin-action').val('select').selectmenu('refresh');
});

$(document).on("pageinit", '#plugins-browse', function(event) {
  $.ajax({
    url: "/api/plugins/search",
    timeout: 20000
  }).done(function(data) {
    var p, _i, _len, _ref;
    _ref = data.plugins;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      addBrowsePlugin(p);
    }
    return $('#plugin-browse-list').listview("refresh");
  }).fail(ajaxAlertFail);
  return $('#plugin-browse-list').on("click", '#add-to-config', function(event, ui) {
    var plugin;
    plugin = $(this).parent('li').data('plugin');
    return $.post("/api/plugins/add", {
      plugins: [plugin.name]
    }).done(function(data) {
      var text;
      text = null;
      if (data.added.length > 0) {
        text = __('Added %s to the config. Plugin will be auto installed on next start.', plugin.name);
        text += " " + __("Please restart pimatic.");
      } else {
        text = __('The plugin %s was allready in the config.', plugin.name);
      }
      showToast(text);
    }).fail(ajaxAlertFail);
  });
});

addBrowsePlugin = function(plugin) {
  var id, li;
  id = "plugin-browse-" + plugin.name;
  li = $($('#plugin-browse-template').html());
  li.data('plugin', plugin);
  li.attr('id', id);
  li.find('.name').text(plugin.name);
  li.find('.description').text(plugin.description);
  li.find('.version').text(plugin.version);
  return $('#plugin-browse-list').append(li);
};

$.ajaxSetup({
  timeout: 7000
});

$(document).ajaxStart(function() {
  console.log('ajax start');
  return $.mobile.loading("show", {
    text: "Loading...",
    textVisible: true,
    textonly: false
  });
});

$(document).ajaxStop(function() {
  return $.mobile.loading("hide");
});

ajaxShowToast = function(data, textStatus, jqXHR) {
  return showToast((data.message != null ? message : 'done'));
};

ajaxAlertFail = function(jqXHR, textStatus, errorThrown) {
  var data, e, message;
  data = null;
  try {
    data = $.parseJSON(jqXHR.responseText);
  } catch (_error) {
    e = _error;
  }
  message = (data != null ? data.error : void 0) != null ? data.error : (errorThrown != null) && errorThrown !== "" ? message = errorThrown : textStatus === 'error' ? message = 'no connection' : message = textStatus;
  return alert(__(message));
};

voiceCallback = function(matches) {
  return $.get("/api/speak", {
    word: matches
  }, function(data) {
    showToast(data);
    return $("#talk").blur();
  });
};

showToast = (typeof device !== "undefined" && device !== null) && (device.showToast != null) ? device.showToast : function(msg) {
  return $('#toast').text(msg).toast().toast('show');
};

__ = function() {
  var a, args, text, translated, _i, _len;
  text = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  translated = text;
  if (locale[text] != null) {
    translated = locale[text];
  } else {
    console.log('no translation yet:', text);
  }
  for (_i = 0, _len = args.length; _i < _len; _i++) {
    a = args[_i];
    translated = translated.replace(/%s/, a);
  }
  return translated;
};
