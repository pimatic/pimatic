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