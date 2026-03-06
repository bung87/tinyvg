# TinyVG writer implementation

import strutils, strformat
import core

# Writer for TinyVG text format
proc writeTinyVG*(doc: TinyVGDocument): string =
  ## Write a TinyVGDocument to text format string
  var output = ""
  
  # Write header
  output.add("(tvg\n")
  output.add(fmt("  {doc.header.version}\n"))
  output.add("  (\n")
  output.add(fmt("    {doc.header.width} {doc.header.height} {doc.header.scale} {doc.header.format} {doc.header.precision}\n"))
  output.add("  )\n")
  
  # Write palette
  output.add("  (\n")
  for color in doc.palette:
    if color.a == 1.0:
      output.add(fmt("    ({color.r:.3f} {color.g:.3f} {color.b:.3f})\n"))
    else:
      output.add(fmt("    ({color.r:.3f} {color.g:.3f} {color.b:.3f} {color.a:.3f})\n"))
  output.add("  )\n")
  
  # Write commands
  output.add("  (\n")
  for cmd in doc.commands:
    output.add("    (\n")
    
    case cmd.kind
    of fill_rectangles:
      output.add("      fill_rectangles\n")
      # Write fill style
      case cmd.fillStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.fillStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      
      # Write rectangles
      output.add("      (\n")
      for rect in cmd.rectangles:
        output.add(fmt("        ({rect.x} {rect.y} {rect.width} {rect.height})\n"))
      output.add("      )\n")
    
    of outline_fill_rectangles:
      output.add("      outline_fill_rectangles\n")
      # Write fill style
      case cmd.fillStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.fillStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write rectangles
      output.add("      (\n")
      for rect in cmd.rectangles:
        output.add(fmt("        ({rect.x} {rect.y} {rect.width} {rect.height})\n"))
      output.add("      )\n")
    
    of draw_lines:
      output.add("      draw_lines\n")
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write lines
      output.add("      (\n")
      for line in cmd.lines:
          output.add(fmt("        (({line.start.x} {line.start.y}) ({line.endPoint.x} {line.endPoint.y}))\n"))
      output.add("      )\n")
    
    of draw_line_loop:
      output.add("      draw_line_loop\n")
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write points
      output.add("      (\n")
      for point in cmd.points:
        output.add(fmt("        ({point.x} {point.y})\n"))
      output.add("      )\n")
    
    of draw_line_strip:
      output.add("      draw_line_strip\n")
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write points
      output.add("      (\n")
      for point in cmd.points:
        output.add(fmt("        ({point.x} {point.y})\n"))
      output.add("      )\n")
    
    of fill_polygon:
      output.add("      fill_polygon\n")
      # Write fill style
      case cmd.fillStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.fillStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      
      # Write points
      output.add("      (\n")
      for point in cmd.points:
        output.add(fmt("        ({point.x} {point.y})\n"))
      output.add("      )\n")
    
    of outline_fill_polygon:
      output.add("      outline_fill_polygon\n")
      # Write fill style
      case cmd.fillStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.fillStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write points
      output.add("      (\n")
      for point in cmd.points:
        output.add(fmt("        ({point.x} {point.y})\n"))
      output.add("      )\n")
    
    of draw_line_path:
      output.add("      draw_line_path\n")
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write start point
      output.add(fmt("      ({cmd.startPoint.x} {cmd.startPoint.y})\n"))
      
      # Write path nodes
      output.add("      (\n")
      for node in cmd.pathNodes:
        var lineWidthStr = if node.lineWidthChange == -1.0: "-" else: $node.lineWidthChange
        
        case node.kind
        of horiz:
          output.add(fmt("        (horiz {lineWidthStr} {node.horizX})\n"))
        of vert:
          output.add(fmt("        (vert {lineWidthStr} {node.vertY})\n"))
        of line:
          output.add(fmt("        (line {lineWidthStr} {node.lineX} {node.lineY})\n"))
        of bezier:
          output.add(fmt("        (bezier {lineWidthStr} ({node.bezierControl1.x} {node.bezierControl1.y}) ({node.bezierControl2.x} {node.bezierControl2.y}) ({node.bezierEndPoint.x} {node.bezierEndPoint.y}))\n"))
        of quadratic_bezier:
          output.add(fmt("        (quadratic_bezier {lineWidthStr} ({node.quadControl.x} {node.quadControl.y}) ({node.quadEndPoint.x} {node.quadEndPoint.y}))\n"))
        of arc_ellipse:
          var largeArcStr = if node.arcLargeArc: "true" else: "false"
          var sweepStr = if node.arcSweep: "true" else: "false"
          output.add(fmt("        (arc_ellipse {lineWidthStr} {node.arcRadiusX} {node.arcRadiusY} {node.arcAngle} {largeArcStr} {sweepStr} ({node.arcEndPoint.x} {node.arcEndPoint.y}))\n"))
        of arc_circle:
          var largeArcStr = if node.circleLargeArc: "true" else: "false"
          var sweepStr = if node.circleSweep: "true" else: "false"
          output.add(fmt("        (arc_circle {lineWidthStr} {node.circleRadius} {largeArcStr} {sweepStr} ({node.circleEndPoint.x} {node.circleEndPoint.y}))\n"))
        of close:
          output.add(fmt("        (close {lineWidthStr})\n"))
      output.add("      )\n")
    
    of fill_path:
      output.add("      fill_path\n")
      # Write fill style
      case cmd.fillStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.fillStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      
      # Write start point
      output.add(fmt("      ({cmd.startPoint.x} {cmd.startPoint.y})\n"))
      
      # Write path nodes
      output.add("      (\n")
      for node in cmd.pathNodes:
        var lineWidthStr = if node.lineWidthChange == -1.0: "-" else: $node.lineWidthChange
        
        case node.kind
        of horiz:
          output.add(fmt("        (horiz {lineWidthStr} {node.horizX})\n"))
        of vert:
          output.add(fmt("        (vert {lineWidthStr} {node.vertY})\n"))
        of line:
          output.add(fmt("        (line {lineWidthStr} {node.lineX} {node.lineY})\n"))
        of bezier:
          output.add(fmt("        (bezier {lineWidthStr} ({node.bezierControl1.x} {node.bezierControl1.y}) ({node.bezierControl2.x} {node.bezierControl2.y}) ({node.bezierEndPoint.x} {node.bezierEndPoint.y}))\n"))
        of quadratic_bezier:
          output.add(fmt("        (quadratic_bezier {lineWidthStr} ({node.quadControl.x} {node.quadControl.y}) ({node.quadEndPoint.x} {node.quadEndPoint.y}))\n"))
        of arc_ellipse:
          var largeArcStr = if node.arcLargeArc: "true" else: "false"
          var sweepStr = if node.arcSweep: "true" else: "false"
          output.add(fmt("        (arc_ellipse {lineWidthStr} {node.arcRadiusX} {node.arcRadiusY} {node.arcAngle} {largeArcStr} {sweepStr} ({node.arcEndPoint.x} {node.arcEndPoint.y}))\n"))
        of arc_circle:
          var largeArcStr = if node.circleLargeArc: "true" else: "false"
          var sweepStr = if node.circleSweep: "true" else: "false"
          output.add(fmt("        (arc_circle {lineWidthStr} {node.circleRadius} {largeArcStr} {sweepStr} ({node.circleEndPoint.x} {node.circleEndPoint.y}))\n"))
        of close:
          output.add(fmt("        (close {lineWidthStr})\n"))
      output.add("      )\n")
    
    of outline_fill_path:
      output.add("      outline_fill_path\n")
      # Write fill style
      case cmd.fillStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.fillStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.fillStyle.linearStartPoint.x} {cmd.fillStyle.linearStartPoint.y}) ({cmd.fillStyle.linearEndPoint.x} {cmd.fillStyle.linearEndPoint.y}) {cmd.fillStyle.linearStartColorIndex} {cmd.fillStyle.linearEndColorIndex})\n"))
      
      # Write line style
      case cmd.lineStyle.kind
      of flat:
        output.add(fmt("      (flat {cmd.lineStyle.flatColorIndex})\n"))
      of linear:
        output.add(fmt("      (linear ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      of radial:
        output.add(fmt("      (radial ({cmd.lineStyle.linearStartPoint.x} {cmd.lineStyle.linearStartPoint.y}) ({cmd.lineStyle.linearEndPoint.x} {cmd.lineStyle.linearEndPoint.y}) {cmd.lineStyle.linearStartColorIndex} {cmd.lineStyle.linearEndColorIndex})\n"))
      
      # Write line width
      output.add(fmt("      {cmd.lineWidth}\n"))
      
      # Write start point
      output.add(fmt("      ({cmd.startPoint.x} {cmd.startPoint.y})\n"))
      
      # Write path nodes
      output.add("      (\n")
      for node in cmd.pathNodes:
        var lineWidthStr = if node.lineWidthChange == -1.0: "-" else: $node.lineWidthChange
        
        case node.kind
        of horiz:
          output.add(fmt("        (horiz {lineWidthStr} {node.horizX})\n"))
        of vert:
          output.add(fmt("        (vert {lineWidthStr} {node.vertY})\n"))
        of line:
          output.add(fmt("        (line {lineWidthStr} {node.lineX} {node.lineY})\n"))
        of bezier:
          output.add(fmt("        (bezier {lineWidthStr} ({node.bezierControl1.x} {node.bezierControl1.y}) ({node.bezierControl2.x} {node.bezierControl2.y}) ({node.bezierEndPoint.x} {node.bezierEndPoint.y}))\n"))
        of quadratic_bezier:
          output.add(fmt("        (quadratic_bezier {lineWidthStr} ({node.quadControl.x} {node.quadControl.y}) ({node.quadEndPoint.x} {node.quadEndPoint.y}))\n"))
        of arc_ellipse:
          var largeArcStr = if node.arcLargeArc: "true" else: "false"
          var sweepStr = if node.arcSweep: "true" else: "false"
          output.add(fmt("        (arc_ellipse {lineWidthStr} {node.arcRadiusX} {node.arcRadiusY} {node.arcAngle} {largeArcStr} {sweepStr} ({node.arcEndPoint.x} {node.arcEndPoint.y}))\n"))
        of arc_circle:
          var largeArcStr = if node.circleLargeArc: "true" else: "false"
          var sweepStr = if node.circleSweep: "true" else: "false"
          output.add(fmt("        (arc_circle {lineWidthStr} {node.circleRadius} {largeArcStr} {sweepStr} ({node.circleEndPoint.x} {node.circleEndPoint.y}))\n"))
        of close:
          output.add(fmt("        (close {lineWidthStr})\n"))
      output.add("      )\n")
    
    of text_hint:
      output.add("      text_hint\n")
      output.add(fmt("      ({cmd.centerX} {cmd.centerY})\n"))
      output.add(fmt("      {cmd.rotation}\n"))
      output.add(fmt("      {cmd.height}\n"))
      output.add(fmt("      \"{cmd.content}\"\n"))
      output.add("      (\n")
      for glyph in cmd.glyphs:
        output.add(fmt("        ({glyph.startOffset} {glyph.endOffset})\n"))
      output.add("      )\n")
    
    output.add("    )\n")
  
  output.add("  )\n")
  output.add(")\n")
  
  result = output

proc writeTinyVG*(doc: TinyVGDocument; filename: string) =  
  ## Write a TinyVGDocument to a file
  let text = writeTinyVG(doc)
  writeFile(filename, text)
