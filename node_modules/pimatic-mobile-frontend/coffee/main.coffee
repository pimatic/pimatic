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


# add-item-page
# ----------

$(document).on "pageinit", '#add-item', (event) ->
  $('#actuator-items').on "click", 'li', ->
    li = $ this
    if li.hasClass 'added' then return
    actuatorId = li.data('actuator-id')
    $.get("/add-actuator/#{actuatorId}")
      .done( (data) ->
        li.data('icon', 'check')
        li.addClass('added')
        li.buttonMarkup({ icon: "check" })
      ).fail(ajaxAlertFail)

  $('#sensor-items').on "click", 'li', ->
    li = $ this
    if li.hasClass 'added' then return
    sensorId = li.data('sensor-id')
    $.get("/add-sensor/#{sensorId}")
      .done( (data) ->
      li.data('icon', 'check')
      li.addClass('added')
      li.buttonMarkup({ icon: "check" })
    ).fail(ajaxAlertFail)

$(document).on "pagebeforeshow", '#add-item', (event) ->
  $.get("/api/list/actuators")
    .done( (data) ->
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
    ).fail(ajaxAlertFail)


  $.get("/api/list/sensors")
    .done( (data) ->
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
    ).fail(ajaxAlertFail)


# edit-rule-page
# --------------

$(document).on "pageinit", '#edit-rule', (event) ->
  $('#edit-rule').on "submit", '#edit-rule-form', ->
    ruleId = $('#edit-rule-id').val()
    ruleText = $('#edit-rule-text').val()
    action = $('#edit-rule-form').data('action')
    $.post("/api/rule/#{ruleId}/#{action}", rule: ruleText)
      .done( (data) ->
        if data.success then $.mobile.changePage('#index',{transition: 'slide', reverse: true})    
        else alert data.error
      ).fail(ajaxAlertFail)
    return false

  $('#edit-rule').on "click", '#edit-rule-remove', ->
    ruleId = $('#edit-rule-id').val()
    $.get("/api/rule/#{ruleId}/remove")
      .done( (data) ->
        if data.success then $.mobile.changePage('#index',{transition: 'slide', reverse: true})    
        else alert data.error
      ).fail(ajaxAlertFail)
    return false

  $(document).on "pagebeforeshow", '#edit-rule', (event) ->
    action = $('#edit-rule-form').data('action')
    switch action
      when 'add'
        $('#edit-rule h3').text __('Edit rule')
        $('#edit-rule-id').textinput('enable')
        $('#edit-rule-advanced').hide()
      when 'update'
        $('#edit-rule h3').text __('Add new rule')
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
  $.get("/api/messages")
    .done( (data) ->
      for entry in data.messages
        addLogMessage entry
      $('#log-messages').listview('refresh') 
      socket.on 'log', (entry) -> 
        addLogMessage entry
        $('#log-messages').listview('refresh') 
    ).fail(ajaxAlertFail)

  $('#log').on "click", '#clear-log', (event, ui) ->
    $.get("/clear-log")
      .done( ->
        $('#log-messages').empty()
       $('#log-messages').listview('refresh') 
        errorCount = 0
        updateErrorCount()
      ).fail(ajaxAlertFail)


addLogMessage = (entry) ->
  li = $ $('#log-message-template').html()
  li.find('.level').text(entry.level).addClass(entry.level)
  li.find('.msg').text(entry.msg)
  $('#log-messages').append li


# plugins-page
# ---------

$(document).on "pageinit", '#plugins', (event) ->
  $.get("/api/plugins/installed")
    .done( (data) ->
      addPlugin(p) for p in data.plugins
      $('#plugin-list').listview("refresh")
      $("#plugin-list input[type='checkbox']").checkboxradio()
    ).fail(ajaxAlertFail)

  $('#plugins').on "click", '#plugin-do-action', (event, ui) ->
    val = $('#select-plugin-action').val()
    if val is 'select' then return alert __('Please select a action first')
    selected = []
    for ele in $ '#plugin-list input[type="checkbox"]'
      ele = $ ele
      if ele.is(':checked')
        selected.push(ele.data 'plugin-name')
    $.post("/api/plugins/#{val}", plugins: selected)
      .done( (data) ->
        past = (if val is 'add' then 'added' else 'removed')
        showToast data[past].length + __(" plugins #{past}") + "." +
         (if data[past].length > 0 then " " + __("Please restart pimatic.") else "")
        uncheckAllPlugins()
        return
      ).fail(ajaxAlertFail)

uncheckAllPlugins = () ->
  for ele in $ '#plugin-list input[type="checkbox"]'
    $(ele).prop("checked", false).checkboxradio("refresh")


addPlugin = (plugin) ->
  id = "plugin-#{plugin.name}"
  li = $ $('#plugin-template').html()
  li.attr('id', id)
  checkBoxId = "cb-#{id}"
  li.find('.name').text(plugin.name)
  li.find('.description').text(plugin.description)
  li.find('.version').text(plugin.version)
  li.find('.homepage').text(plugin.homepage).attr('href', plugin.homepage)
  li.find('.active').text(if plugin.active then __('activated') else __('deactived'))
  li.find("input[type='checkbox']").attr('id', checkBoxId).attr('name', checkBoxId)
    .data('plugin-name', plugin.name)
  $('#plugin-list').append li

$(document).on "pagebeforeshow", '#plugins', (event) ->
  $('#select-plugin-action').val('select').selectmenu('refresh')


# plugins-browse-page
# ---------

$(document).on "pageinit", '#plugins-browse', (event) ->
  $.ajax(
    url: "/api/plugins/search"
    timeout: 20000 #ms
  ).done( (data) ->
      addBrowsePlugin(p) for p in data.plugins
      $('#plugin-browse-list').listview("refresh")
    ).fail(ajaxAlertFail)

  $('#plugin-browse-list').on "click", '#add-to-config', (event, ui) ->
    plugin = $(this).parent('li').data('plugin')
    $.post("/api/plugins/add", plugins: [plugin.name])
      .done( (data) ->
        text = null
        if data.added.length > 0
          text = __('Added %s to the config. Plugin will be auto installed on next start.', 
                    plugin.name)
          text +=  " " + __("Please restart pimatic.")
        else
          text = __('The plugin %s was already in the config.', plugin.name)
        showToast text
        return
      ).fail(ajaxAlertFail)

addBrowsePlugin = (plugin) ->
  id = "plugin-browse-#{plugin.name}"
  li = $ $('#plugin-browse-template').html()
  li.data('plugin', plugin)
  li.attr('id', id)
  li.find('.name').text(plugin.name)
  li.find('.description').text(plugin.description)
  li.find('.version').text(plugin.version)
  #li.find('.installed').text(if plugin.active then __('activated') else __('deactived'))
  $('#plugin-browse-list').append li





# General
# -------

$.ajaxSetup timeout: 7000 #ms

$(document).ajaxStart ->
  console.log 'ajax start'
  $.mobile.loading "show",
    text: "Loading..."
    textVisible: true
    textonly: false

$(document).ajaxStop ->
  $.mobile.loading "hide"


ajaxShowToast = (data, textStatus, jqXHR) -> 
  showToast (if data.message? then message else 'done')

ajaxAlertFail = (jqXHR, textStatus, errorThrown) ->
  data = null
  try
    data = $.parseJSON jqXHR.responseText
  catch e 
    #ignore error
  message =
    if data?.error?
      data.error
    else if errorThrown? and errorThrown != ""
      message = errorThrown
    else if textStatus is 'error'
      message = 'no connection'
    else
      message = textStatus

  alert __(message)

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
    (msg) -> $('#toast').text(msg).toast().toast('show')

__ = (text, args...) -> 
  translated = text
  if locale[text]? then translated = locale[text]
  else console.log 'no translation yet:', text
    
  for a in args
    translated = translated.replace /%s/, a
  return translated
