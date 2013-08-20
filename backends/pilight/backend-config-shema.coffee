# define the convict config-schema
module.exports =
  pilightSendBinary:
    doc: "The path to the pilight-send command"
    format: String
    default: "pilight-send"