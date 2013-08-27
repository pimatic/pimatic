$(document).on "pageinit", (a) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  $(".switch").bind "change", (event, ui) ->
    console.log event
    console.log ui
    actuatorID = $(this).data "actuator-id"
    actuatorAction = $(this).val()
    $.get "/api/actuator/#{actuatorID}/#{actuatorAction}"  , (data) ->
      device?.showToast "fertig"

  socket = io.connect("/")
  socket.on "switch-status", (data) ->
    value = (if state then "turnOn" else "turnOff")
    $("flip-#{data.id}").val value


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

voiceCallback = (matches) ->
  $.get "/api/speak",
    word: matches
  , (data) ->
    device.showToast data
    $("#talk").blur()

