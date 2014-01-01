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




