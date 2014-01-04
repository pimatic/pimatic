# plugins-page
# ---------


$(document).on "pageinit", '#updates', (event) ->
  $('#updates .message').text __('Searching for updates...')



  $.ajax(
    url: "/api/plugins/search"
    timeout: 30000 #ms
  ).done( (data) ->
    $('#plugin-browse-list').empty()
    allPlugins = data.plugins
    for p in data.plugins
      addBrowsePlugin(p)
      if p.isNewer
        $("#plugin-#{plugin.name} .update-available").text __('update available')
    if $('#plugin-browse-list').data('mobileListview')?
      $('#plugin-browse-list').listview("refresh")
    disableInstallButtons()
  ).fail(ajaxAlertFail)


