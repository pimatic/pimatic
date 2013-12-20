module.exports = (grunt) ->

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    coffeelint:
      app: [
        "*.coffee"
        "node_modules/pimatic-*/*.coffee"
        "lib/**/*.coffee"
        "test/**/*.coffee"
      ]
      options:
        no_trailing_whitespace:
          level: "ignore"
        max_line_length:
          value: 100
        indentation:
          value: 2
          level: "error"

    groc:
      javascript: [] #file list is in the groc.json file
      options: grunt.file.readJSON(".groc.json")

    "ftp-deploy":
      build:
        auth:
          host: "sweetpi.de"
          port: 21 #,

        #authKey: 'key1'
        src: "docs"
        dest: "/pimatic/pimatic/docs"

    mochaTest:
      test:
        options:
          reporter: "spec"
          require: ['coffee-errors'] #needed for right line numbers in errors
        src: ["test/**/*"]
      # blanket is used to record coverage
      testBlanket:
        options:
          reporter: "dot"
          require: ["coverage/blanket"]
        src: ["test/**/*"]
      coverage:
        options:
          reporter: "html-cov"
          quiet: true
          captureFile: "coverage/coverage.html"

        src: ["test/**/*."]

  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-groc"
  grunt.loadNpmTasks "grunt-ftp-deploy"
  grunt.loadNpmTasks "grunt-mocha-test"
  grunt.registerTask "publish-plugins", "publish all pimatic-plugins", ->
    done = @async()
    cwd = process.cwd()
    plugins = require("fs").readdirSync("./node_modules")
    require("async").eachSeries plugins, ((file, cb) ->
      if file.indexOf("pimatic-") is 0
        grunt.log.writeln "publishing: " + file
        process.chdir cwd + "/node_modules/" + file
        child = grunt.util.spawn(
          opts:
            stdio: "inherit"
          cmd: "npm"
          args: ["publish"]
        , (err) ->
          console.log err.message  if err
          cb()
        )
      else
        cb()
    ), (err) ->
      process.chdir cwd
      done()

  
  # Default task(s).
  grunt.registerTask "default", ["coffeelint", "mochaTest:test", "groc"]
  grunt.registerTask "test", ["coffeelint", "mochaTest:test"]
  grunt.registerTask "coverage", ["mochaTest:testBlanket", "mochaTest:coverage"]
