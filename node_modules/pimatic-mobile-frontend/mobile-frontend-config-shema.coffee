# #mobile-frontend configuration options

# Defines a `node-convict` config-shema and exports it.
module.exports =
  items:
    doc: "The items to display"
    format: Array
    default: []
  mode:
    doc: "production or development mode"
    format: ["production", "development"]
    default: "production"