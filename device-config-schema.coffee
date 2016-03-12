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
            confirm:
              description: "Ask the user to confirm the button press"
              type: "boolean"
              default: false
  }
  VariablesDevice: {
    title: "VariablesDevice config"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
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
              description: "The unit of the variable. Only works if type is a number."
              type: "string"
              required: false
            label:
              description: "A custom label to use in the frontend."
              type: "string"
              required: false
            discrete:
              description: "
                Should be set to true if the value does not change continuously over time.
              "
              type: "boolean"
              required: false
            acronym:
              description: "Acronym to show as value label in the frontend"
              type: "string"
              required: false
  }
  VariableInputDevice: {
    title: "VariablesDevice config"
    type: "object"
    extensions: ["xLink"]
    properties:
      variable:
        description: "The variable to modify on input change"
        type: "string"
      type:
        description: "The type of the input"
        type: "string"
        default: "string"
        enum: ["string", "number"]
      min:
        description: "Minimum value for numeric values"
        type: "number"
        required: false
      max:
        description: "Maximum value for numeric values"
        type: "number"
        required: false
      step:
        description: "Step size for minus and plus buttons for numeric values"
        type: "number"
        default: 1
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
  DummyContactSensor:
    title: "DummyContactSensor config"
    type: "object"
    extensions: ["xLink", "xClosedLabel", "xOpenedLabel"]
    properties: {}
  DummyPresenceSensor:
    title: "DummyPresenceSensor config"
    type: "object"
    extensions: ["xLink", "xClosedLabel", "xOpenedLabel"]
    properties:
      autoReset:
        description: """Reset the state to absent after resetTime"""
        type: "boolean"
        default: true
      resetTime:
        description: "Time after that the presence value is reseted to absent."
        type: "integer"
        default: 10000
  DummyHeatingThermostat: {
    title: "DummyHeatingThermostat config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      comfyTemp:
        description: "The defined comfy temperature"
        type: "number"
        default: 21
      ecoTemp:
        description: "The defined eco mode temperature"
        type: "number"
        default: 17
      guiShowValvePosition:
        description: "Show the valve position in the GUI"
        type: "boolean"
        default: true
      guiShowModeControl:
        description: "Show the mode buttons in the GUI"
        type: "boolean"
        default: true
      guiShowPresetControl:
        description: "Show the preset temperatures in the GUI"
        type: "boolean"
        default: true
      guiShowTemperatureInput:
        description: "Show the temperature input spinbox in the GUI"
        type: "boolean"
        default: true
  }
  DummyTemperatureSensor:
    title: "DummyTemperatureSensor config options"
    type: "object"
    extensions: ["xLink","xAttributeOptions"]
    properties: {}
  Timer:
    title: "timer config"
    type: "object"
    extensions: ["xLink"]
    properties: {
      resolution:
        description: "The interval the timer is updated in seconds"
        type: "number"
        default: 1
    }
}
