# TinyVG Binary Format Tests

import unittest
import os
import tinyvg

proc testBinaryRoundTrip() =
  test "Binary format round-trip":
    # Create a document
    var doc1 = initTinyVGDocument(400, 768)
    var red = doc1.addColor(1.0, 0.0, 0.0)
    var green = doc1.addColor(0.0, 1.0, 0.0)
    doc1.addFillRectangle(25, 25, 100, 15, red)
    doc1.addOutlineFillRectangle(25, 105, 100, 15, red, green, 2.5)

    # Write to binary file
    writeTinyVGBinary(doc1, "test_binary.tvg")

    # Read back
    var doc2 = readTinyVGBinary("test_binary.tvg")

    # Verify
    check doc2.header.width == doc1.header.width
    check doc2.header.height == doc1.header.height
    check doc2.palette.len == doc1.palette.len
    check doc2.commands.len == doc1.commands.len

    # Clean up
    removeFile("test_binary.tvg")

proc testAdditionalCommands() =
  test "Additional drawing commands":
    var doc = initTinyVGDocument(400, 768)
    var red = doc.addColor(1.0, 0.0, 0.0)
    var green = doc.addColor(0.0, 1.0, 0.0)
    var blue = doc.addColor(0.0, 0.0, 1.0)

    # Draw line loop (triangle)
    doc.addDrawLineLoop(
      [(VGFloat(100.0), VGFloat(100.0)), 
       (VGFloat(150.0), VGFloat(50.0)), 
       (VGFloat(200.0), VGFloat(100.0))], 
      red, VGFloat(2.0)
    )

    # Draw line strip
    doc.addDrawLineStrip(
      [(VGFloat(50.0), VGFloat(200.0)), 
       (VGFloat(100.0), VGFloat(250.0)), 
       (VGFloat(150.0), VGFloat(200.0)), 
       (VGFloat(200.0), VGFloat(250.0))], 
      green, VGFloat(1.5)
    )

    # Fill polygon
    doc.addFillPolygon(
      [(VGFloat(300.0), VGFloat(100.0)), 
       (VGFloat(350.0), VGFloat(50.0)), 
       (VGFloat(400.0), VGFloat(100.0)), 
       (VGFloat(350.0), VGFloat(150.0))], 
      blue
    )

    # Outline fill polygon
    doc.addOutlineFillPolygon(
      [(VGFloat(300.0), VGFloat(200.0)), 
       (VGFloat(350.0), VGFloat(150.0)), 
       (VGFloat(400.0), VGFloat(200.0)), 
       (VGFloat(350.0), VGFloat(250.0))], 
      blue, red, VGFloat(2.0)
    )

    check doc.commands.len == 4
    check doc.commands[0].kind == draw_line_loop
    check doc.commands[1].kind == draw_line_strip
    check doc.commands[2].kind == fill_polygon
    check doc.commands[3].kind == outline_fill_polygon

proc testPathCommands() =
  test "Path-based commands":
    var doc = initTinyVGDocument(400, 768)
    var red = doc.addColor(1.0, 0.0, 0.0)
    var green = doc.addColor(0.0, 1.0, 0.0)

    # Create a path with various node types
    var pathNodes = [
      newPathLine(100, 100),
      newPathHoriz(200),
      newPathVert(200),
      newPathBezier(250, 150, 300, 250, 350, 200),
      newPathClose()
    ]

    # Draw line path
    doc.addDrawLinePath(
      (VGFloat(50.0), VGFloat(50.0)), 
      pathNodes, red, VGFloat(2.0)
    )

    # Fill path
    doc.addFillPath(
      (VGFloat(200.0), VGFloat(300.0)), 
      pathNodes, green
    )

    check doc.commands.len == 2
    check doc.commands[0].kind == draw_line_path
    check doc.commands[1].kind == fill_path
    check doc.commands[0].pathNodes.len == 5
    check doc.commands[1].pathNodes.len == 5

proc testTextHint() =
  test "Text hint command":
    var doc = initTinyVGDocument(400, 768)

    var glyphs = [(0, 5), (6, 10)]
    doc.addTextHint(200.0, 400.0, 0.0, 24.0, "Hello World", glyphs)

    check doc.commands.len == 1
    check doc.commands[0].kind == text_hint
    check doc.commands[0].content == "Hello World"
    check doc.commands[0].centerX == 200.0
    check doc.commands[0].centerY == 400.0

# Run all tests
when isMainModule:
  testBinaryRoundTrip()
  testAdditionalCommands()
  testPathCommands()
  testTextHint()
  echo "All binary format tests passed!"
