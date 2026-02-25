# TinyVG tests

import unittest
import os
import tinyvg

proc testCreateDocument() =  
  test "Create TinyVG document":
    var doc = initTinyVGDocument(400, 768, 1.0)
    check doc.header.width == 400
    check doc.header.height == 768
    check doc.header.scale == 1.0
    check doc.header.format == u8888
    check doc.header.precision == default
    check doc.palette.len == 0
    check doc.commands.len == 0

proc testAddColor() =  
  test "Add colors to palette":
    var doc = initTinyVGDocument(400, 768)
    var red = doc.addColor(1.0, 0.0, 0.0)
    var green = doc.addColor(0.0, 1.0, 0.0)
    var blue = doc.addColor(0.0, 0.0, 1.0, 0.5)
    
    check doc.palette.len == 3
    check doc.palette[red].r == 1.0
    check doc.palette[red].g == 0.0
    check doc.palette[red].b == 0.0
    check doc.palette[red].a == 1.0
    
    check doc.palette[green].r == 0.0
    check doc.palette[green].g == 1.0
    check doc.palette[green].b == 0.0
    check doc.palette[green].a == 1.0
    
    check doc.palette[blue].r == 0.0
    check doc.palette[blue].g == 0.0
    check doc.palette[blue].b == 1.0
    check doc.palette[blue].a == 0.5

proc testAddRectangles() =  
  test "Add rectangles":
    var doc = initTinyVGDocument(400, 768)
    var red = doc.addColor(1.0, 0.0, 0.0)
    var green = doc.addColor(0.0, 1.0, 0.0)
    
    doc.addFillRectangle(25, 25, 100, 15, red)
    doc.addOutlineFillRectangle(25, 105, 100, 15, red, green, 2.5)
    
    check doc.commands.len == 2
    check doc.commands[0].kind == fill_rectangles
    check doc.commands[0].fillStyle.kind == flat
    check doc.commands[0].fillStyle.flatColorIndex == red
    check doc.commands[0].rectangles.len == 1
    check doc.commands[0].rectangles[0].x == 25
    check doc.commands[0].rectangles[0].y == 25
    check doc.commands[0].rectangles[0].width == 100
    check doc.commands[0].rectangles[0].height == 15
    
    check doc.commands[1].kind == outline_fill_rectangles
    check doc.commands[1].fillStyle.kind == flat
    check doc.commands[1].fillStyle.flatColorIndex == red
    check doc.commands[1].lineStyle.kind == flat
    check doc.commands[1].lineStyle.flatColorIndex == green
    check doc.commands[1].lineWidth == 2.5
    check doc.commands[1].rectangles.len == 1
    check doc.commands[1].rectangles[0].x == 25
    check doc.commands[1].rectangles[0].y == 105
    check doc.commands[1].rectangles[0].width == 100
    check doc.commands[1].rectangles[0].height == 15

proc testRoundTrip() =
  test "Round trip: write and read back":
    # Create a document
    var doc1 = initTinyVGDocument(400, 768)
    var red = doc1.addColor(1.0, 0.0, 0.0)
    var green = doc1.addColor(0.0, 1.0, 0.0)
    doc1.addFillRectangle(25, 25, 100, 15, red)
    doc1.addOutlineFillRectangle(25, 105, 100, 15, red, green, 2.5)

    # Write to file
    writeTinyVG(doc1, "test_output.tvg")

    # Read back
    var doc2 = readTinyVG("test_output.tvg")

    # Verify
    check doc2.header.width == doc1.header.width
    check doc2.header.height == doc1.header.height
    check doc2.palette.len == doc1.palette.len
    check doc2.commands.len == doc1.commands.len

    # Clean up
    removeFile("test_output.tvg")

proc testParseExample() =
  test "Parse example from specification":
    var example = """
    (tvg 1
      (400 768 1/32 u8888 default)
      (
        (0.906 0.663 0.075)
        (1.000 0.471 0.000)
        (0.251 1.000 0.000)
        (0.722 0.000 0.302)
        (0.373 0.000 0.620)
        (0.573 0.882 0.220)
      )
      (
        (
          fill_rectangles
          (flat 0)
          (
            (25 25 100 15)
            (25 45 100 15)
            (25 65 100 15)
          )
        )
        (
          outline_fill_rectangles
          (flat 0)
          (linear (150 660) (250 710) 1 2 )
          2.5
          (
            (25 105 100 15)
            (25 125 100 15)
            (25 145 100 15)
          )
        )
        (
          draw_lines
          (radial (325 50) (375 75) 1 2 )
          2.5
          (
            ((25 185) (125 195))
            ((25 195) (125 205))
            ((25 205) (125 215))
            ((25 215) (125 225))
          )
        )
      )
    )
    """

    var doc = parseTinyVG(example)
    check doc.header.version == 1
    check doc.header.width == 400
    check doc.header.height == 768
    check doc.palette.len == 6
    check doc.commands.len == 3
    check doc.commands[0].kind == fill_rectangles
    check doc.commands[1].kind == outline_fill_rectangles
    check doc.commands[2].kind == draw_lines

# Run all tests
when isMainModule:
  testCreateDocument()
  testAddColor()
  testAddRectangles()
  testRoundTrip()
  testParseExample()
  echo "All tests passed!"
