$(document).on "pageinit", (a) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  $(".switch").each (i, o) ->
    $(o).bind "vclick", (event, ui) =>
      actorId = $(o).data("actorid")
      actorAction = $(o).data("actoraction")
      $.get "/api/actor/#{actorId}/#{actorAction}"  , (data) ->
        device?.showToast "fertig"



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
