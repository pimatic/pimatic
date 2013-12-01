# #pilight configuration options

# Defines a `node-convict` config-shema and exports it.
module.exports =
  pilightSendBinary:
    doc: "The path to the pilight-send command"
    format: String
    default: "pilight-send"