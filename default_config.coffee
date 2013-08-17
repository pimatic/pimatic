module.exports =
  auth: 
    #username and password for the web interface
    username: "admin"
    password: ""
    disableAuthentication: no  
  # Section: server
  # ---------------
  # Which server should be startet. currently https- and http-server are supported
  server:
    # Settings for the *http*-server
    httpServer:
      enabled: yes
      port: 80
    # Settings fpr the 'https*-server
    httpsServer: 
      enabled: no
      port: 443
      keyFile: ".cert/privatekey.pem"
      certFile: ".cert/certificate.pem"
  # Section: frontends
  # ------------------
  # Array of frontends to load:
  frontends: [
    { 
      module: "rest" 
    }
    { 
      module: "speak" 
    }
    { 
      module: "mobile" 
      actorsToDisplay: [
#        define your actors to display here:
#        { id: "light" }
#        { id: "printer" }
      ]
    }
#    { 
#      module: "filebrowser" 
#      mappings: [
#        {
#          path: "/files"
#          directory: "/media/usb1"
#        }
#      ]
#    }
#    { 
#      module: "redirect" 
#      routes: [
#        {
#          path: "/printer"
#          redirect: "http://192.168.1.2:631/printers/"
#        }
#      ]
#    }
  ]
  # Section: backends
  # ------------------
  # Array of backends to load:
  backends: [
#    { 
#      module: "rpi433mhz" 
#      binary: "/home/pi/source/433.92-Raspberry-Pi/send"
#    }
#    { 
#      module: "sispmctl" 
#      binary: "sispmctl"
#    }
  ]
  # Section: actors
  # ------------------
  # Array of actors to add:
  actors: [
#    { 
#      id: "light"
#      class: "Rpi433Mhz" 
#      name: "Licht"
#      outletUnit: 0
#      outletId: 123456 
#    }
#    { 
#      id: "printer"
#      class: "Sispmctl" 
#      name: "Printer"
#      outletUnit: 2
#    }
  ]