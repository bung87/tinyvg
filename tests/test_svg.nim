# SVG Parser Tests

import unittest
import tinyvg
import tinyvg/svg

const testSvg = """<?xml version="1.0" encoding="UTF-8"?>
<svg width="200" height="200" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="80" height="60" fill="red" stroke="black" stroke-width="2"/>
  <circle cx="150" cy="50" r="30" fill="blue"/>
  <line x1="10" y1="100" x2="190" y2="100" stroke="green" stroke-width="3"/>
  <polygon points="100,120 120,180 80,180" fill="yellow" stroke="orange" stroke-width="1"/>
</svg>"""

proc testSvgParser() =
  test "Parse SVG document":
    let svgDoc = parseSvg(testSvg)
    
    check svgDoc.width == 200
    check svgDoc.height == 200
    check svgDoc.elements.len == 4
    
    # Check rect
    check svgDoc.elements[0].kind == svgRect
    check svgDoc.elements[0].x == 10
    check svgDoc.elements[0].y == 10
    check svgDoc.elements[0].width == 80
    check svgDoc.elements[0].height == 60
    check svgDoc.elements[0].fill == "red"
    check svgDoc.elements[0].stroke == "black"
    check svgDoc.elements[0].strokeWidth == 2
    
    # Check circle
    check svgDoc.elements[1].kind == svgCircle
    check svgDoc.elements[1].x == 150
    check svgDoc.elements[1].y == 50
    check svgDoc.elements[1].r == 30
    check svgDoc.elements[1].fill == "blue"
    
    # Check line
    check svgDoc.elements[2].kind == svgLine
    check svgDoc.elements[2].x1 == 10
    check svgDoc.elements[2].y1 == 100
    check svgDoc.elements[2].x2 == 190
    check svgDoc.elements[2].y2 == 100
    check svgDoc.elements[2].stroke == "green"
    
    # Check polygon
    check svgDoc.elements[3].kind == svgPolygon
    check svgDoc.elements[3].points.len == 3
    check svgDoc.elements[3].points[0].x == 100
    check svgDoc.elements[3].points[0].y == 120

proc testSvgToTinyVG() =
  test "Convert SVG to TinyVG":
    let svgDoc = parseSvg(testSvg)
    let tvgDoc = svgToTinyVG(svgDoc)
    
    check tvgDoc.header.width == 200
    check tvgDoc.header.height == 200
    check tvgDoc.palette.len > 0
    check tvgDoc.commands.len == 4
    
    echo "\nConverted TinyVG document:"
    echo "  Width: ", tvgDoc.header.width
    echo "  Height: ", tvgDoc.header.height
    echo "  Colors: ", tvgDoc.palette.len
    echo "  Commands: ", tvgDoc.commands.len

proc testColorParsing() =
  test "Parse SVG colors":
    check svg.parseColor("#ff0000") == TinyVGColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
    check svg.parseColor("#00ff00") == TinyVGColor(r: 0.0, g: 1.0, b: 0.0, a: 1.0)
    check svg.parseColor("#0000ff") == TinyVGColor(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
    check svg.parseColor("red") == TinyVGColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
    check svg.parseColor("green") == TinyVGColor(r: 0.0, g: 1.0, b: 0.0, a: 1.0)
    check svg.parseColor("blue") == TinyVGColor(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
    check svg.parseColor("none").a == 0.0

proc testPathParsing() =
  test "Parse SVG path data":
    let pathData = "M 10 10 L 90 10 L 90 90 L 10 90 Z"
    let nodes = parsePathData(pathData)
    
    # Path: M(->line), L, L, L, Z = 5 nodes expected
    check nodes.len >= 4  # At least 4 nodes (move/line, 2 lines, close)
    check nodes[0].kind == line  # Move becomes line
    check nodes[^1].kind == close  # Last should be close

proc testEllipse() =
  test "Parse SVG ellipse":
    const ellipseSvg = """<?xml version="1.0"?>
<svg width="100" height="100">
  <ellipse cx="50" cy="50" rx="30" ry="20" fill="purple"/>
</svg>"""
    let svgDoc = parseSvg(ellipseSvg)
    
    check svgDoc.elements.len == 1
    check svgDoc.elements[0].kind == svgEllipse
    check svgDoc.elements[0].x == 50
    check svgDoc.elements[0].y == 50
    check svgDoc.elements[0].ellipseRx == 30
    check svgDoc.elements[0].ellipseRy == 20

proc testPolyline() =
  test "Parse SVG polyline":
    const polylineSvg = """<?xml version="1.0"?>
<svg width="100" height="100">
  <polyline points="0,0 50,25 50,75 0,100" fill="none" stroke="black"/>
</svg>"""
    let svgDoc = parseSvg(polylineSvg)
    
    check svgDoc.elements.len == 1
    check svgDoc.elements[0].kind == svgPolyline
    check svgDoc.elements[0].points.len == 4

# Run all tests
when isMainModule:
  testSvgParser()
  testSvgToTinyVG()
  testColorParsing()
  testPathParsing()
  testEllipse()
  testPolyline()
  echo "\nAll SVG tests passed!"
