module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffeelint: {
      app: ['*.coffee', 'node_modules/sweetpi-*/*.coffee', 'lib/**/*.coffee'],
      options: {
        'no_trailing_whitespace': {
          level: 'ignore'
        },
        'max_line_length': {
          value: 100
        },
        'indentation': {
          value: 2,
          level: 'error'
        }
      }
    },
    groc: {
      javascript: [], //file list is in the groc.json file
      options: grunt.file.readJSON('.groc.json')
    },
    'ftp-deploy': {
      build: {
        auth: {
          host: 'sweetpi.de',
          port: 21//,
          //authKey: 'key1'
        },
        src: 'docs',
        dest: '/sweetpi/sweetpi-server/docs'
      }
    },
    cafemocha: {
      mainTests: {
          src: 'test/**/*.coffee',
          options: {
              ui: 'bdd',
              reporter: 'spec'
              /*coverage: true*/
          }
      }
    }
  });

  grunt.loadNpmTasks('grunt-coffeelint');
  grunt.loadNpmTasks('grunt-groc');
  grunt.loadNpmTasks('grunt-ftp-deploy');
  grunt.loadNpmTasks('grunt-cafe-mocha');
  
  grunt.registerTask('publish-plugins', 'publish all sweetpi-plugins', function() {
    var done = this.async();
    var cwd = process.cwd();
    var plugins = require('fs').readdirSync("./node_modules");

    require('async').eachSeries(plugins, function(file, cb){
      if(file.indexOf("sweetpi-") == 0) {
        grunt.log.writeln("publishing: "+ file);
        process.chdir(cwd + "/node_modules/" + file);
        var child = grunt.util.spawn({
          opts: {stdio: 'inherit'},
          cmd: 'npm',
          args: ['publish']
        });

        child.on('close', function(code){
          cb(null);
        });
      } else {
        cb(null);
      }
    }, function(err){
      process.chdir(cwd);
      done();  
    });
  });

  // Does not work...
  // grunt.registerTask('sweetpi-server', 'Starts the server', function() {
  //   grunt.util.spawn({
  //     cmd: 'coffee',
  //     args: ['sweetpi.coffee']
  //   });
  // });

  // Default task(s).
  grunt.registerTask('default', ['coffeelint', 'cafemocha','groc']);
  //grunt.registerTask('run', ['coffeelint', 'sweetpi-server']);
};