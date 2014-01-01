fs = require("fs")
path = require("path")

cssIncImages = (cssFile) ->
  imgRegex = /url\s?\(['"]?(.*?)(?=['"]?\))/g
  css = fs.readFileSync(cssFile, "utf-8")
  while match = imgRegex.exec(css)
    imgPath = path.join(path.dirname(cssFile), match[1])
    try
      img = fs.readFileSync(imgPath, "base64")
      ext = imgPath.substr(imgPath.lastIndexOf(".") + 1)
      css = css.replace(match[1], "data:image/" + ext + ";base64," + img)
    catch err
      console.log "Image not found (%s).", imgPath
  
   fs.writeFileSync(cssFile, css, 'utf-8') #you can overwrite the original file with this line

walk = (dir) ->
  files = fs.readdirSync(dir)
  for i of files
    continue  unless files.hasOwnProperty(i)
    name = dir + "/" + files[i]
    if fs.statSync(name).isDirectory()
      walk name
    else
      if name.match(/\.css$/)?
        console.log name

walk '../app/css'
