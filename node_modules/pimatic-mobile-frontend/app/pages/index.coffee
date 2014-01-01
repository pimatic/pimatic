# index-page
# ----------

$(document).on "pagecreate", '#index', (event) ->
  loadData()

$(document).on "pageinit", '#index', (event) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  socket = io.connect("/", 
    'connect timeout': 5000
    'reconnection delay': 500
    'reconnection limit': 2000 # the max delay
    'max reconnection attempts': Infinity
  )

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
    showToast entry.msg
    console.log entry

  socket.on 'reconnect', ->
    $.mobile.loading "hide"
    loadData()

  socket.on 'disconnect', ->
   $.mobile.loading "show",
    text: __("connection lost, retying")+'...'
    textVisible: true
    textonly: false

  onConnectionError = ->
    $.mobile.loading "show",
      text: __("could not connect, retying")+'...'
      textVisible: true
      textonly: false
    setTimeout ->
      socket.socket.connect(->
        $.mobile.loading "hide"
        loadData()
      )
    , 2000

  socket.on 'error', onConnectionError
  socket.on 'connect_error', onConnectionError

  $('#index #items').on "change", ".switch",(event, ui) ->
    actuatorId = $(this).data('actuator-id')
    actuatorAction = if $(this).val() is 'on' then 'turnOn' else 'turnOff'
    $.get("/api/actuator/#{actuatorId}/#{actuatorAction}")
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)


  $('#index #rules').on "click", ".rule", (event, ui) ->
    ruleId = $(this).data('rule-id')
    rule = rules[ruleId]
    $('#edit-rule-form').data('action', 'update')
    $('#edit-rule-text').val("if " + rule.condition + " then " + rule.action)
    $('#edit-rule-id').val(ruleId)
    event.stopPropagation()
    return true

  $('#index #rules').on "click", "#add-rule", (event, ui) ->
    $('#edit-rule-form').data('action', 'add')
    $('#edit-rule-text').val("")
    $('#edit-rule-id').val("")
    event.stopPropagation()
    return true

  $("#items").sortable(
    items: "li.sortable"
    forcePlaceholderSize: true
    placeholder: "sortable-placeholder"
    handle: ".handle"
    cursor: "move"
    revert: 100
    scroll: true
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
  )

  $("#items .handle").disableSelection()

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
  return

loadData = () ->
  $.get("/data.json")
    .done( (data) ->
      actuators = []
      sensors = []
      rules = []
      $('#items .item').remove()
      addItem(item) for item in data.items
      $('#rules .rule').remove()
      addRule(rule) for rule in data.rules
      errorCount = data.errorCount
      updateErrorCount()
    ) #.fail(ajaxAlertFail)

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
  li.append $('<div class="ui-icon-alt handle">
    <div class="ui-icon ui-icon-bars"></div>
  </div>')
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
