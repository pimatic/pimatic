module.exports = {
  title: "pimatic device config schemas"
  ButtonsDevice: {
    title: "ButtonsDevice config"
    type: "object"
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
    properties:
      variables:
        description: "Variables to display"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          properties:
            name:
              type: "string"
            expression:
              type: "string"
            type:
              type: "string"
              default: "string"
              enum: ["string", "number"]
   
  }
}