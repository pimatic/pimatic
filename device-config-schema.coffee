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
              description: """
                The expression to use to get the value. Can be just a variable name ($myVar), 
                a calculation ($myVar + 10) or a string interpolation ("Test: {$myVar}!")
                """
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
}