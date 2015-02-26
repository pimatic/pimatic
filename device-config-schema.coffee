module.exports = {
  title: "pimatic device config schemas"
  ButtonsDevice: {
    title: "ButtonsDevice config"
    type: "object"
    extensions: ["xLink"]
    properties:
      buttons:
        description: "Buttons to display"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          properties:
            id:
              type: "string"
            text:
              type: "string"
  }
  VariablesDevice: {
    title: "VariablesDevice config"
    type: "object"
    extensions: ["xLink"]
    properties:
      variables:
        description: "Variables to display"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          required: ["name", "expression"]
          properties:
            name:
              description: "Name for the corresponding attribute."
              type: "string"
            expression:
              description: "
                The expression to use to get the value. Can be just a variable name ($myVar), 
                a calculation ($myVar + 10) or a string interpolation (\"Test: {$myVar}!\")
                "
              type: "string"
            type:
              description: "The type of the variable."
              type: "string"
              default: "string"
              enum: ["string", "number"]
            unit:
              description: "The unit of the variable, only works if type is number."
              type: "string"
            label: 
              description: "A custom label to use in the frontend."
              type: "string"
            discrete:
              description: "
                Should be set to true if the value does not change continuously over time.
              "
              type: "boolean"
  }
  DummySwitch:
    title: "DummySwitch config"
    type: "object"
    extensions: ["xLink", "xConfirm", "xOnLabel", "xOffLabel"]
    properties: {}
  DummyDimmer:
    title: "DummyDimmer config"
    type: "object"
    extensions: ["xLink"]
    properties: {}
  DummyShutter:
    title: "DummyShutter config"
    type: "object"
    extensions: ["xLink"]
    properties: {}
  DummyHeatingThermostat: {
    title: "DummyHeatingThermostat config options"
    type: "object"
    properties:
      comfyTemp:
        description: "The defined comfy temperature"
        type: "number"
        default: 21
      ecoTemp:
        description: "The defined eco mode temperature"
        type: "number"
        default: 17
      guiShowModeControl: 
        description: "Show the mode buttons in the gui"
        type: "boolean"
        default: true
      guiShowPresetControl:
        description: "Show the preset temperatures in the gui"
        type: "boolean"
        default: true
      guiShowTemperatueInput:
        description: "Show the temperature input spinbox in the gui"
        type: "boolean"
        default: true        
  }
}