$(document).on "pagecreate", (event) ->
  $.get "/data.json", (data) ->
    addSwitch(actuator) for actuator in data.actuators
    addRule(rule) for rule in data.rules


$(document).on "pageinit", (event) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  socket = io.connect("/")
  socket.on "switch-status", (data) ->
    if data.state?
      value = (if data.state then "on" else "off")
      $("#flip-#{data.id}").val(value).slider('refresh')


$.ajaxSetup timeout: 7000 #ms

$(document).ajaxStart ->
  $.mobile.loading "show",
    text: "Lade..."
    textVisible: true
    textonly: false

$(document).ajaxStop ->
  $.mobile.loading "hide"

$(document).ajaxError (event, jqxhr, settings, exception) ->
  error = undefined
  if exception
    error = "Fehler: " + exception
  else
    error = "Ein Fehler ist aufgetreten."
  alert error

addSwitch = (actuator) ->
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
    .bind "change", (event, ui) ->
      actuatorAction = if $(this).val() is 'on' then 'turnOn' else 'turnOff'
      $.get "/api/actuator/#{actuator.id}/#{actuatorAction}"  , (data) ->
        device?.showToast "fertig"
  $('#actuators').append li
  $('#actuators').listview('refresh')

addRule = (rule) ->
  li = $ $('#rule-template').html()
  li.attr('id', "rule-#{rule.id}")   
  li.find('.condition').text(rule.condition)
  li.find('.action').text(rule.action)

  $('#rules').append li
  $('#rules').listview('refresh')

voiceCallback = (matches) ->
  $.get "/api/speak",
    word: matches
  , (data) ->
    device.showToast data
    $("#talk").blur()