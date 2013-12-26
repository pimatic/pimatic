require('blanket')({
  // Only files that match the pattern will be instrumented
  pattern: [
    'pimatic/lib/',
    'pimatic/node_modules/pimatic-cron/cron.coffee',
    'pimatic/node_modules/pimatic-filebrowser/filebrowser.coffee',
    'pimatic/node_modules/pimatic-log-reader/log-reader.coffee',
    'pimatic/node_modules/pimatic-mobile-frontend/mobile-frontend.coffee',
    'pimatic/node_modules/pimatic-pilight/pilight.coffee',
    'pimatic/node_modules/pimatic-ping/ping.coffee',
    'pimatic/node_modules/pimatic-redirect/redirect.coffee',
    'pimatic/node_modules/pimatic-rest-api/rest-api.coffee',
    'pimatic/node_modules/pimatic-sispmctl/sispmctl.coffee',
    'pimatic/node_modules/pimatic-speak-api/speak-api.coffee'
  ],
  loader: "./node-loaders/coffee-script"
});