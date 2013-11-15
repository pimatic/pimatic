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