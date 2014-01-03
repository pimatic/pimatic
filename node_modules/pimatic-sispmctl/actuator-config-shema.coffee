# #SispmctlSwitch actuator configuration options

# Defines a `node-convict` config-shema and exports it.
module.exports =
  outletUnit:
    doc: "The outlet unit number"
    format: "int"
    default: null
  device: 
    # If you have more than on device then you gan select the device the outlet belons to.
    doc: "The device to use. Devices can be listed by \"sudo sispmctl -s\""
    format: "int"
    default: 0