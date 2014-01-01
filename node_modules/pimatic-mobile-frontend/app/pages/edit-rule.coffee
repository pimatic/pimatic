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