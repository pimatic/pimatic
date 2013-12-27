# #gpio actuator configuration options

# Defines a `node-convict` config-shema and exports it.
module.exports =
  GpioPresents:
    gpio:
      doc: "The gpio pin"
      format: "int"
      default: null
    inverted:
      doc: "LOW = present?"
      format: Boolean
      default: false
