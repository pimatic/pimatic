require('blanket')({
  // Only files that match the pattern will be instrumented
  pattern: [
    'pimatic/lib/',
    'pimatic/node_modules/pimatic-pilight/pilight.coffee'
  ],
  loader: "./node-loaders/coffee-script"
});