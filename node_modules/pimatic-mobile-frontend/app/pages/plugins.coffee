# plugins-page
# ---------

installedPlugins = null
allPlugins = null


$(document).on "pageinit", '#plugins', (event) ->
  $.get("/api/plugins/installed")
    .done( (data) ->
      installedPlugins = data.plugins
      addPlugin(p) for p in data.plugins
      $('#plugin-list').listview("refresh")
      $("#plugin-list input[type='checkbox']").checkboxradio()
    ).fail( ajaxAlertFail
    ).complete( ->
      $.ajax(
        url: "/api/plugins/search"
        timeout: 20000 #ms
      ).done( (data) ->
        allPlugins = data.plugins
        addBrowsePlugin(p) for p in data.plugins
        if $('#plugin-browse-list').data('listview')?
          $('#plugin-browse-list').listview("refresh")
      ).fail(ajaxAlertFail)
    )

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
