# #gpio actuator configuration options

# Defines a `node-convict` config-shema and exports it.
module.exports =
  GpioSwitch:
    gpio:
      doc: "The gpio pin"
      format: "int"
      default: null