# Example: Generate HTML5 Canvas rendering from TinyVG

import tinyvg

proc main() =
  # Create a sample TinyVG document
  var doc = initTinyVGDocument(800, 600)
  
  # Add colors to palette
  var red = doc.addColor(1.0, 0.0, 0.0)
  var green = doc.addColor(0.0, 1.0, 0.0)
  var blue = doc.addColor(0.0, 0.0, 1.0)
  var yellow = doc.addColor(1.0, 1.0, 0.0)
  var white = doc.addColor(1.0, 1.0, 1.0)
  var black = doc.addColor(0.0, 0.0, 0.0)
  
  # Add some rectangles
  doc.addFillRectangle(50, 50, 150, 100, red)
  doc.addOutlineFillRectangle(250, 50, 150, 100, green, blue, 3.0)
  
  # Add a triangle (line loop)
  doc.addDrawLineLoop(
    [(VGFloat(100.0), VGFloat(250.0)), 
     (VGFloat(150.0), VGFloat(200.0)), 
     (VGFloat(200.0), VGFloat(250.0))], 
    yellow, VGFloat(2.0)
  )
  
  # Add a polygon
  doc.addFillPolygon(
    [(VGFloat(400.0), VGFloat(200.0)), 
     (VGFloat(450.0), VGFloat(150.0)), 
     (VGFloat(500.0), VGFloat(200.0)), 
     (VGFloat(450.0), VGFloat(250.0))], 
    blue
  )
  
  # Add a bezier path
  var pathNodes = [
    newPathLine(VGFloat(300), VGFloat(400)),
    newPathBezier(
      VGFloat(350), VGFloat(350), 
      VGFloat(450), VGFloat(450), 
      VGFloat(500), VGFloat(400)
    ),
    newPathClose()
  ]
  doc.addFillPath(
    (VGFloat(250.0), VGFloat(350.0)), 
    pathNodes, 
    green
  )
  
  # Add text hint
  var glyphs = [(0, 5), (6, 11)]
  doc.addTextHint(
    VGFloat(400.0), VGFloat(500.0), 
    VGFloat(0.0), VGFloat(32.0), 
    "Hello TinyVG", 
    glyphs
  )
  
  # Generate and save HTML
  writeHTML(doc, "examples/output.html", "TinyVG Canvas Example")
  echo "Generated: examples/output.html"
  
  # Also print the JavaScript code
  echo "\n=== Generated JavaScript ==="
  echo renderToCanvas(doc)

when isMainModule:
  main()
