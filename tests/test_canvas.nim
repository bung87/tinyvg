# TinyVG HTML5 Canvas Renderer Tests

import unittest
import os
import strutils
import tinyvg

proc testCanvasRenderer() =
  test "Canvas renderer generates JavaScript code":
    var doc = initTinyVGDocument(400, 300)
    var red = doc.addColor(1.0, 0.0, 0.0)
    var green = doc.addColor(0.0, 1.0, 0.0)
    var blue = doc.addColor(0.0, 0.0, 1.0)
    
    # Add some shapes
    doc.addFillRectangle(50, 50, 100, 80, red)
    doc.addOutlineFillRectangle(200, 50, 100, 80, green, blue, 3.0)
    
    # Generate canvas code
    let jsCode = renderToCanvas(doc)
    
    check "var canvas = document.getElementById" in jsCode
    check "var ctx = canvas.getContext('2d')" in jsCode
    check "ctx.fillRect" in jsCode
    check "ctx.strokeRect" in jsCode
    check "rgba(255, 0, 0" in jsCode
    check "rgba(0, 255, 0" in jsCode
    
    echo "\nGenerated JavaScript code:"
    echo "=========================="
    echo jsCode

proc testHTMLRenderer() =
  test "HTML renderer generates complete HTML page":
    var doc = initTinyVGDocument(400, 300)
    var red = doc.addColor(1.0, 0.0, 0.0)
    var green = doc.addColor(0.0, 1.0, 0.0)
    
    doc.addFillRectangle(50, 50, 100, 80, red)
    doc.addDrawLineLoop(
      [(VGFloat(100.0), VGFloat(200.0)), 
       (VGFloat(150.0), VGFloat(150.0)), 
       (VGFloat(200.0), VGFloat(200.0))], 
      green, VGFloat(2.0)
    )
    
    # Generate HTML
    let html = renderToHTML(doc, "Test Canvas")
    
    check "<!DOCTYPE html>" in html
    check "<canvas id=\"tinyvg-canvas\"" in html
    check "width=400" in html
    check "height=300" in html
    check "<script>" in html
    check "</script>" in html
    check "Test Canvas" in html
    
    # Write to file for manual inspection
    writeHTML(doc, "test_output.html", "Test Canvas")
    
    check fileExists("test_output.html")
    
    # Clean up
    removeFile("test_output.html")

proc testPolygonRendering() =
  test "Polygon rendering generates correct canvas code":
    var doc = initTinyVGDocument(400, 300)
    var blue = doc.addColor(0.0, 0.0, 1.0)
    
    doc.addFillPolygon([
      (VGFloat(200.0), VGFloat(50.0)),
      (VGFloat(250.0), VGFloat(100.0)),
      (VGFloat(200.0), VGFloat(150.0)),
      (VGFloat(150.0), VGFloat(100.0))
    ], blue)
    
    let jsCode = renderToCanvas(doc)
    
    check "ctx.beginPath()" in jsCode
    check "ctx.moveTo" in jsCode
    check "ctx.lineTo" in jsCode
    check "ctx.closePath()" in jsCode
    check "ctx.fill()" in jsCode

proc testPathRendering() =
  test "Path rendering generates correct canvas code":
    var doc = initTinyVGDocument(400, 300)
    var red = doc.addColor(1.0, 0.0, 0.0)
    
    var pathNodes = [
      newPathLine(VGFloat(100), VGFloat(100)),
      newPathBezier(
        VGFloat(150), VGFloat(50), 
        VGFloat(200), VGFloat(150), 
        VGFloat(250), VGFloat(100)
      ),
      newPathClose()
    ]
    
    doc.addFillPath(
      (VGFloat(50.0), VGFloat(50.0)), 
      pathNodes, 
      red
    )
    
    let jsCode = renderToCanvas(doc)
    
    check "ctx.beginPath()" in jsCode
    check "var curX = 50.0" in jsCode
    check "var curY = 50.0" in jsCode
    check "ctx.moveTo(curX, curY)" in jsCode
    check "ctx.lineTo(100.0, 100.0)" in jsCode
    check "ctx.bezierCurveTo" in jsCode
    check "ctx.closePath()" in jsCode
    check "ctx.fill()" in jsCode

proc testTextRendering() =
  test "Text hint rendering generates correct canvas code":
    var doc = initTinyVGDocument(400, 300)
    
    var glyphs = [(0, 5), (6, 11)]
    doc.addTextHint(
      VGFloat(200.0), VGFloat(150.0), 
      VGFloat(0.0), VGFloat(24.0), 
      "Hello World", 
      glyphs
    )
    
    let jsCode = renderToCanvas(doc)
    
    check "ctx.save()" in jsCode
    check "ctx.translate(200.0, 150.0)" in jsCode
    check "ctx.rotate(0.0)" in jsCode
    check "ctx.font" in jsCode
    check "ctx.fillText('Hello World', 0, 0)" in jsCode
    check "ctx.restore()" in jsCode

# Run all tests
when isMainModule:
  testCanvasRenderer()
  testHTMLRenderer()
  testPolygonRendering()
  testPathRendering()
  testTextRendering()
  echo "\nAll canvas renderer tests passed!"
