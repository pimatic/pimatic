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
      files: [
        "./README.md"
        "./startup.coffee"
        "./config-shema.coffee"
        "./lib/*.coffee"
        "./node_modules/pimatic-cron/*.coffee"
        "./node_modules/pimatic-cron/README.md"
        "./node_modules/pimatic-ping/*.coffee"
        "./node_modules/pimatic-ping/README.md"
        "./node_modules/pimatic-filebrowser/*.coffee"
        "./node_modules/pimatic-filebrowser/README.md"
        "./node_modules/pimatic-log-reader/*.coffee"
        "./node_modules/pimatic-log-reader/README.md"
        "./node_modules/pimatic-mobile-frontend/*.coffee"
        "./node_modules/pimatic-mobile-frontend/README.md"
        "./node_modules/pimatic-pilight/*.coffee"
        "./node_modules/pimatic-pilight/README.md"
        "./node_modules/pimatic-redirect/*.coffee"
        "./node_modules/pimatic-redirect/README.md"
        "./node_modules/pimatic-rest-api/*.coffee"
        "./node_modules/pimatic-rest-api/README.md"
        "./node_modules/pimatic-sispmctl/*.coffee"
        "./node_modules/pimatic-sispmctl/README.md"
        "./node_modules/pimatic-speak-api/*.coffee"
        "./node_modules/pimatic-speak-api/README.md"
      ]
      options: 
        root: "."
        out: "docs"
        "repository-url": "https://github.com/pimatic/pimatic"
        strip: false

    "ftp-deploy":
      build:
        auth:
          host: "sweetpi.de"
          port: 21
        authKey: 'sweetpi.de'
        src: "docs"
        dest: "/sweetpi/pimatic/docs"

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
