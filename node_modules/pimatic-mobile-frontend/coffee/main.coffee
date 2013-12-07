actuators = []
rules = []

$(document).on "pagecreate", '#index', (event) ->
  $.get "/data.json", (data) ->
    for item in data.items
      if item.template?
        if item.template is "switch"
          addSwitch(item)
        else addActuator(item)
      else addActuator(item)


    addRule(rule) for rule in data.rules


$(document).on "pageinit", '#index', (event) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  socket = io.connect("/")
  socket.on "switch-status", (data) ->
    if data.state?
      value = (if data.state then "on" else "off")
      $("#flip-#{data.id}").val(value).slider('refresh')

  socket.on "rule-add", (rule) -> addRule rule
  socket.on "rule-update", (rule) -> updateRule rule
  socket.on "rule-remove", (rule) -> removeRule rule

  $('#index #items').on "change", ".switch",(event, ui) ->
    actuatorId = $(this).data('actuator-id')
    actuatorAction = if $(this).val() is 'on' then 'turnOn' else 'turnOff'
    $.get "/api/actuator/#{actuatorId}/#{actuatorAction}"  , (data) ->
      device?.showToast "fertig"

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
  $('#items').append li
  $('#items').listview('refresh')

addActuator = (actuator) ->
  actuators[actuator.id] = actuator
  li = $ $('#actuator-template').html()
  li.find('label').text(actuator.name)
  if actuator.error?
    li.find('.error').text(actuator.error)
  $('#items').append li
  $('#items').listview('refresh')


addRule = (rule) ->
  rules[rule.id] = rule 
  li = $ $('#rule-template').html()
  li.attr('id', "rule-#{rule.id}")   
  li.find('a').data('rule-id', rule.id)
  li.find('.condition').text(rule.condition)
  li.find('.action').text(rule.action)
  $('#add-rule').before li
  $('#rules').listview('refresh')

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

voiceCallback = (matches) ->
  $.get "/api/speak",
    word: matches
  , (data) ->
    device.showToast data
    $("#talk").blur()