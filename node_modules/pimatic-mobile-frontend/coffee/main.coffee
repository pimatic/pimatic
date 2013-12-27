actuators = []
sensors = []
rules = []
errorCount = 0
socket = null

# index-page
# ----------

$(document).on "pagecreate", '#index', (event) ->
  loadData()

$(document).on "pageinit", '#index', (event) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  socket = io.connect("/", 'connect timeout': 5000)
  socket.on "switch-status", (data) ->
    if data.state?
      value = (if data.state then "on" else "off")
      $("#flip-#{data.id}").val(value).slider('refresh')

  socket.on "sensor-value", (data) -> updateSensorValue data

  socket.on "rule-add", (rule) -> addRule rule
  socket.on "rule-update", (rule) -> updateRule rule
  socket.on "rule-remove", (rule) -> removeRule rule
  socket.on "item-add", (item) -> addItem item


  socket.on 'log', (entry) -> 
    if entry.level is 'error' 
      errorCount++
      updateErrorCount()
    console.log entry

  socket.on 'reconnect', ->
    $.mobile.loading "hide"
    loadData()

  socket.on 'disconnect', ->
   $.mobile.loading "show",
    text: "No Connection"
    textVisible: true
    textonly: true

  socket.on 'connect_failed', ->
    $.mobile.loading "show",
      text: "Could not connect"
      textVisible: true
      textonly: true


  $('#index #items').on "change", ".switch",(event, ui) ->
    actuatorId = $(this).data('actuator-id')
    actuatorAction = if $(this).val() is 'on' then 'turnOn' else 'turnOff'
    $.get "/api/actuator/#{actuatorId}/#{actuatorAction}"  , (data) ->
      showToast "done"

  $('#index #rules').on "click", ".rule", (event, ui) ->
    ruleId = $(this).data('rule-id')
    rule = rules[ruleId]
    $('#edit-rule-form').data('action', 'update')
    $('#edit-rule-text').val("if " + rule.condition + " then " + rule.action)
    $('#edit-rule-id').val(ruleId)
    return true

  $('#index #rules').on "click", "#add-rule", (event, ui) ->
    $('#edit-rule-form').data('action', 'add')
    $('#edit-rule-text').val("")
    $('#edit-rule-id').val("")
    return true

  $("#items").sortable(
    items: "li.sortable"
    forcePlaceholderSize: true
    placeholder: "sortable-placeholder"
    start: (ev, ui) ->
      $("#delete-item").show()
      $("#add-a-item").hide()
      $('#items').listview('refresh')
      ui.item.css('border-bottom-width', '1px')

    stop: (ev, ui) ->
      $("#delete-item").hide()
      $("#add-a-item").show()
      $('#items').listview('refresh')
      ui.item.css('border-bottom-width', '0')
      order = for item in $("#items li.sortable")
        item = $ item
        type: item.data('item-type'), id: item.data('item-id')
      $.post "update-order", order: order
  ).disableSelection()

  $("#delete-item").droppable(
    accept: "li.sortable"
    hoverClass: "ui-state-hover"
    drop: (ev, ui) ->
      item = {
        id: ui.draggable.data('item-id')
        type: ui.draggable.data('item-type')
      }
      $.post 'remove-item', item: item
      if item.type is 'actuator'
        delete actuators[item.id]
      if item.type is 'sensor'
        delete sensors[item.id]
      ui.draggable.remove()
  )

loadData = () ->
  $.get "/data.json", (data) ->
    actuators = []
    sensors = []
    rules = []
    $('#items .item').remove()
    addItem(item) for item in data.items
    $('#rules .rule').remove()
    addRule(rule) for rule in data.rules
    errorCount = data.errorCount
    updateErrorCount()

updateErrorCount = ->
  if $('#error-count').find('.ui-btn-text').length > 0
    $('#error-count').find('.ui-btn-text').text(errorCount)
    try
      $('#error-count').button('refresh')
    catch e
      # ignore: Uncaught Error: cannot call methods on button prior 
      # to initialization; attempted to call method 'refresh' 
  else
    $('#error-count').text(errorCount)
  if errorCount is 0 then $('#error-count').hide()
  else $('#error-count').show()

addItem = (item) ->
  li = if item.template?
    switch item.template 
      when "switch" then buildSwitch(item)
      when "temperature" then buildTemperature(item)
      when "presents" then buildPresents(item)
  else switch item.type
    when 'actuator'
      buildActuator(item)
    when 'sensor'
      buildSensor(item)
  li.data('item-type', item.type)
  li.data('item-id', item.id)
  li.addClass 'item'
  $('#add-a-item').before li
  $('#items').listview('refresh')

buildSwitch = (actuator) ->
  actuators[actuator.id] = actuator
  li = $ $('#switch-template').html()
  li.find('label')
    .attr('for', "flip-#{actuator.id}")
    .text(actuator.name)
  select = li.find('select')
    .attr('name', "flip-#{actuator.id}")
    .attr('id', "flip-#{actuator.id}")             
    .data('actuator-id', actuator.id)
  if actuator.state?
    val = if actuator.state then 'on' else 'off'
    select.find("option[value=#{val}]").attr('selected', 'selected')
  select
    .slider() 
  return li

buildActuator = (actuator) ->
  actuators[actuator.id] = actuator
  li = $ $('#actuator-template').html()
  li.find('label').text(actuator.name)
  if actuator.error?
    li.find('.error').text(actuator.error)
  return li

buildSensor = (sensor) ->
  sensors[sensor.id] = sensor
  li = $ $('#actuator-template').html()
  li.find('label').text(sensor.name)
  if sensor.error?
    li.find('.error').text(sensor.error)
  return li

buildTemperature = (sensor) ->
  sensors[sensor.id] = sensor
  li = $ $('#temperature-template').html()
  li.attr('id', "sensor-#{sensor.id}")     
  li.find('label').text(sensor.name)
  li.find('.temperature .val').text(sensor.values.temperature)
  li.find('.humidity .val').text(sensor.values.humidity)
  return li


buildPresents = (sensor) ->
  sensors[sensor.id] = sensor
  li = $ $('#presents-template').html()
  li.attr('id', "sensor-#{sensor.id}")     
  li.find('label').text(sensor.name)
  if sensor.values.present is true
    li.find('.present .val').text('present').addClass('val-present')
  else 
    li.find('.present .val').text('not present').addClass('val-not-present')
  return li

updateSensorValue = (sensorValue) ->
  li = $("\#sensor-#{sensorValue.id}")
  if sensorValue.name is 'present'
    if sensorValue.value is true
      li.find(".#{sensorValue.name} .val")
        .text('present')
        .addClass('val-present')
        .removeClass('val-not-present')
    else 
      li.find(".#{sensorValue.name} .val")
        .text('not present')
        .addClass('val-not-resent')
        .removeClass('val-present')
  else
    li.find(".#{sensorValue.name} .val").text(sensorValue.value)

addRule = (rule) ->
  rules[rule.id] = rule 
  li = $ $('#rule-template').html()
  li.attr('id', "rule-#{rule.id}")   
  li.find('a').data('rule-id', rule.id)
  li.find('.condition').text(rule.condition)
  li.find('.action').text(rule.action)
  li.addClass 'rule'
  $('#add-rule').before li
  $('#rules').listview('refresh')


# add-item-page
# ----------

$(document).on "pageinit", '#add-item', (event) ->
  $('#actuator-items').on "click", 'li', ->
    li = $ this
    if li.hasClass 'added' then return
    actuatorId = li.data('actuator-id')
    $.get "/add-actuator/#{actuatorId}", (data) ->
      li.data('icon', 'check')
      li.addClass('added')
      li.buttonMarkup({ icon: "check" });

  $('#sensor-items').on "click", 'li', ->
    li = $ this
    if li.hasClass 'added' then return
    sensorId = li.data('sensor-id')
    $.get "/add-sensor/#{sensorId}", (data) ->
      li.data('icon', 'check')
      li.addClass('added')
      li.buttonMarkup({ icon: "check" });


$(document).on "pagebeforeshow", '#add-item', (event) ->
  $.get "/api/list/actuators", (data) ->
    $('#actuator-items .item').remove()
    for a in data.actuators
      li = $ $('#item-add-template').html()
      if actuators[a.id]? 
        li.data('icon', 'check')
        li.addClass('added')
      li.find('label').text(a.name)
      li.data 'actuator-id', a.id
      li.addClass 'item'
      $('#actuator-items').append li
    $('#actuator-items').listview('refresh')

  $.get "/api/list/sensors", (data) ->
    $('#sensor-items .item').remove()
    for s in data.sensors
      li = $ $('#item-add-template').html()
      if sensors[s.id]? 
        li.data('icon', 'check')
        li.addClass('added')
      li.find('label').text(s.name)
      li.data 'sensor-id', s.id
      li.addClass 'item'
      $('#sensor-items').append li
    $('#sensor-items').listview('refresh')


# edit-rule-page
# --------------

$(document).on "pageinit", '#edit-rule', (event) ->
  $('#edit-rule').on "submit", '#edit-rule-form', ->
    ruleId = $('#edit-rule-id').val()
    ruleText = $('#edit-rule-text').val()
    action = $('#edit-rule-form').data('action')
    $.post "/api/rule/#{ruleId}/#{action}", rule: ruleText, (data) ->
      if data.success then $.mobile.changePage('#index',{transition: 'slide', reverse: true})    
      else alert data.error
    return false

  $('#edit-rule').on "click", '#edit-rule-remove', ->
    ruleId = $('#edit-rule-id').val()
    $.get "/api/rule/#{ruleId}/remove", (data) ->
      if data.success then $.mobile.changePage('#index',{transition: 'slide', reverse: true})    
      else alert data.error
    return false

  $(document).on "pagebeforeshow", '#edit-rule', (event) ->
    action = $('#edit-rule-form').data('action')
    switch action
      when 'add'
        $('#edit-rule h3.add').show()
        $('#edit-rule h3.edit').hide()
        $('#edit-rule-id').textinput('enable')
        $('#edit-rule-advanced').hide()
      when 'update'
        $('#edit-rule h3.add').hide()
        $('#edit-rule h3.edit').show()
        $('#edit-rule-id').textinput('disable')
        $('#edit-rule-advanced').show()

updateRule = (rule) ->
  rules[rule.id] = rule 
  li = $("\#rule-#{rule.id}")   
  li.find('.condition').text(rule.condition)
  li.find('.action').text(rule.action)
  $('#rules').listview('refresh')

removeRule = (rule) ->
  delete rules[rule.id]
  $("\#rule-#{rule.id}").remove()
  $('#rules').listview('refresh')  

# log-page
# ---------

$(document).on "pageinit", '#log', (event) ->
  $.get "/api/messages"  , (data) ->
    for entry in data
      addLogMessage entry
    socket.on 'log', (entry) -> 
      addLogMessage entry

  $('#log').on "click", '#clear-log', (event, ui) ->
    $.get "/clear-log", ->
      $('#log-messages').empty()
      errorCount = 0
      updateErrorCount()


addLogMessage = (entry) ->
  li = $ $('#log-message-template').html()
  li.find('.level').text(entry.level).addClass(entry.level)
  li.find('.msg').text(entry.msg)
  $('#log-messages').append li
  $('#log-messages').listview('refresh') 


# General
# -------

$.ajaxSetup timeout: 7000 #ms

$(document).ajaxStart ->
  $.mobile.loading "show",
    text: "Loading..."
    textVisible: true
    textonly: false

$(document).ajaxStop ->
  $.mobile.loading "hide"

$(document).ajaxError (event, jqxhr, settings, exception) ->
  console.log exception
  error = undefined
  if exception
    error = "Error: " + exception
  else
    error = "No Connection"
  alert error

voiceCallback = (matches) ->
  $.get "/api/speak",
    word: matches
  , (data) ->
    showToast data
    $("#talk").blur()

showToast = 
  if device? and device.showToast?
    device.showToast
  else
    (msg) ->
      $("<div class='ui-loader ui-overlay-shadow ui-body-e ui-corner-all'><h3>#{msg}</h3></div>").css(
        display: "block"
        opacity: 0.90
        position: "fixed"
        padding: "7px"
        "text-align": "center"
        width: "270px"
        left: ($(window).width() - 284) / 2
        top: $(window).height() / 2
      ).appendTo($.mobile.pageContainer).delay(1500).fadeOut 400, ->
        $(this).remove()
