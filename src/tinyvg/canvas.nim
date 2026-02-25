# TinyVG HTML5 Canvas Renderer
#
# Generates JavaScript code for rendering TinyVG documents
# using the HTML5 Canvas API.

import std/[strutils, strformat, streams, math]
import core

type
  CanvasRenderer* = object
    ## Renderer that generates JavaScript canvas code
    width*: int
    height*: int
    scale*: float
    indentLevel*: int
    stream*: StringStream  # Use StringStream for efficient string building

proc initCanvasRenderer*(width, height: int; scale: float = 1.0): CanvasRenderer =
  ## Initialize a new canvas renderer
  result = CanvasRenderer(
    width: width,
    height: height,
    scale: scale,
    indentLevel: 0,
    stream: newStringStream()
  )

proc indent(renderer: CanvasRenderer): string =
  ## Generate indentation string using repeat
  result = "  ".repeat(renderer.indentLevel)

proc line(renderer: var CanvasRenderer, code: string) =
  ## Generate a line of code with proper indentation
  renderer.stream.writeLine(indent(renderer) & code)

proc incIndent(renderer: var CanvasRenderer) =
  ## Increase indentation level
  renderer.indentLevel += 1

proc decIndent(renderer: var CanvasRenderer) =
  ## Decrease indentation level
  renderer.indentLevel -= 1

proc escapeJSString(s: string): string =
  ## Escape a string for safe use in JavaScript
  ## Prevents XSS and syntax errors
  result = newStringOfCap(s.len + 16)  # Pre-allocate with some extra space
  for c in s:
    case c
    of '\\': result.add("\\\\")
    of '"': result.add("\\\"")
    of '\n': result.add("\\n")
    of '\r': result.add("\\r")
    of '\t': result.add("\\t")
    of '\b': result.add("\\b")
    of '\f': result.add("\\f")
    of '<': result.add("\\x3c")  # Prevent HTML injection
    of '>': result.add("\\x3e")
    of '&': result.add("\\x26")
    of '\x00'..'\x07', '\x0B', '\x0E'..'\x1F':
      # Control characters (excluding \b=0x08 which is handled above) - escape as hex
      result.add(fmt("\\x{ord(c):02x}"))
    else:
      result.add(c)

proc colorToCSS(color: TinyVGColor): string =
  ## Convert TinyVG color to CSS rgba() format
  let r = int(color.r * 255)
  let g = int(color.g * 255)
  let b = int(color.b * 255)
  let a = color.a
  result = fmt("rgba({r}, {g}, {b}, {a})")

proc generateStyleCode(renderer: var CanvasRenderer, style: TinyVGStyle,
                       palette: TinyVGColorPalette, isFill: bool = true) =
  ## Generate canvas style code (fillStyle or strokeStyle)
  let styleProp = if isFill: "fillStyle" else: "strokeStyle"
  
  case style.kind:
    of flat:
      if style.flatColorIndex >= 0 and style.flatColorIndex < palette.len:
        let color = palette[style.flatColorIndex]
        renderer.line(fmt("ctx.{styleProp} = '{colorToCSS(color)}';"))
      else:
        # Fallback to black if index out of bounds
        renderer.line(fmt("ctx.{styleProp} = 'rgba(0, 0, 0, 1)'; // Warning: color index out of bounds"))
    of linear:
      # Linear gradient
      renderer.line(fmt("var gradient = ctx.createLinearGradient(") &
                       fmt("{style.linearStartPoint.x}, {style.linearStartPoint.y}, ") &
                       fmt("{style.linearEndPoint.x}, {style.linearEndPoint.y});"))
      if style.linearStartColorIndex >= 0 and style.linearStartColorIndex < palette.len:
        let startColor = palette[style.linearStartColorIndex]
        renderer.line(fmt("gradient.addColorStop(0, '{colorToCSS(startColor)}');"))
      if style.linearEndColorIndex >= 0 and style.linearEndColorIndex < palette.len:
        let endColor = palette[style.linearEndColorIndex]
        renderer.line(fmt("gradient.addColorStop(1, '{colorToCSS(endColor)}');"))
      renderer.line(fmt("ctx.{styleProp} = gradient;"))
    of radial:
      # Radial gradient - calculate radius based on distance between points
      let dx = style.radialEndPoint.x - style.radialStartPoint.x
      let dy = style.radialEndPoint.y - style.radialStartPoint.y
      let radius = float32(sqrt(float(dx * dx + dy * dy)))
      renderer.line(fmt("var gradient = ctx.createRadialGradient(") &
                       fmt("{style.radialStartPoint.x}, {style.radialStartPoint.y}, 0, ") &
                       fmt("{style.radialEndPoint.x}, {style.radialEndPoint.y}, {radius});"))
      if style.radialStartColorIndex >= 0 and style.radialStartColorIndex < palette.len:
        let startColor = palette[style.radialStartColorIndex]
        renderer.line(fmt("gradient.addColorStop(0, '{colorToCSS(startColor)}');"))
      if style.radialEndColorIndex >= 0 and style.radialEndColorIndex < palette.len:
        let endColor = palette[style.radialEndColorIndex]
        renderer.line(fmt("gradient.addColorStop(1, '{colorToCSS(endColor)}');"))
      renderer.line(fmt("ctx.{styleProp} = gradient;"))

proc generatePathNodeCode(renderer: var CanvasRenderer, node: TinyVGPathNode) =
  ## Generate code for a single path node
  case node.kind:
    of horiz:
      # Horizontal line to x, keeping current y
      renderer.line(fmt("// Horizontal line to x={node.horizX}"))
      renderer.line(fmt("ctx.lineTo({node.horizX}, curY);"))
      renderer.line(fmt("curX = {node.horizX};"))
    of vert:
      # Vertical line to y, keeping current x
      renderer.line(fmt("// Vertical line to y={node.vertY}"))
      renderer.line(fmt("ctx.lineTo(curX, {node.vertY});"))
      renderer.line(fmt("curY = {node.vertY};"))
    of line:
      # Line to (x, y)
      renderer.line(fmt("ctx.lineTo({node.lineX}, {node.lineY});"))
      renderer.line(fmt("curX = {node.lineX}; curY = {node.lineY};"))
    of bezier:
      # Cubic Bezier curve
      renderer.line(fmt("ctx.bezierCurveTo(") &
                       fmt("{node.bezierControl1.x}, {node.bezierControl1.y}, ") &
                       fmt("{node.bezierControl2.x}, {node.bezierControl2.y}, ") &
                       fmt("{node.bezierEndPoint.x}, {node.bezierEndPoint.y});"))
      renderer.line(fmt("curX = {node.bezierEndPoint.x}; curY = {node.bezierEndPoint.y};"))
    of quadratic_bezier:
      # Quadratic Bezier curve
      renderer.line(fmt("ctx.quadraticCurveTo(") &
                       fmt("{node.quadControl.x}, {node.quadControl.y}, ") &
                       fmt("{node.quadEndPoint.x}, {node.quadEndPoint.y});"))
      renderer.line(fmt("curX = {node.quadEndPoint.x}; curY = {node.quadEndPoint.y};"))
    of arc_ellipse:
      # Elliptical arc - use the renderArc helper
      renderer.line(fmt("renderArc(ctx, curX, curY, {node.arcRadiusX}, {node.arcRadiusY}, ") &
                       fmt("{node.arcAngle}, {node.arcLargeArc}, {node.arcSweep}, ") &
                       fmt("{node.arcEndPoint.x}, {node.arcEndPoint.y});"))
      renderer.line(fmt("curX = {node.arcEndPoint.x}; curY = {node.arcEndPoint.y};"))
    of arc_circle:
      # Circular arc - use the renderArc helper
      renderer.line(fmt("renderArc(ctx, curX, curY, {node.circleRadius}, {node.circleRadius}, ") &
                       fmt("0, {node.circleLargeArc}, {node.circleSweep}, ") &
                       fmt("{node.circleEndPoint.x}, {node.circleEndPoint.y});"))
      renderer.line(fmt("curX = {node.circleEndPoint.x}; curY = {node.circleEndPoint.y};"))
    of close:
      # Close path
      renderer.line("ctx.closePath();")

proc generateRenderCommands*(doc: TinyVGDocument; ctxName: string = "ctx"; renderer: var CanvasRenderer) =
  ## Generate just the rendering commands without canvas setup
  ## Useful when integrating into existing canvas code
  
  # Apply scale
  if doc.header.scale != 1.0:
    renderer.line(fmt("{ctxName}.scale({doc.header.scale}, {doc.header.scale});"))
    renderer.line("")
  
  # Render each command
  for cmd in doc.commands:
    case cmd.kind:
      of fill_rectangles:
        # Fill rectangles
        renderer.line("// Fill rectangles")
        generateStyleCode(renderer, cmd.fillStyle, doc.palette, true)
        for rect in cmd.rectangles:
          renderer.line(fmt("ctx.fillRect({rect.x}, {rect.y}, {rect.width}, {rect.height});"))
        renderer.line("")
      
      of outline_fill_rectangles:
        # Outline fill rectangles
        renderer.line("// Outline fill rectangles")
        # Fill first
        generateStyleCode(renderer, cmd.fillStyle, doc.palette, true)
        for rect in cmd.rectangles:
          renderer.line(fmt("ctx.fillRect({rect.x}, {rect.y}, {rect.width}, {rect.height});"))
        # Then stroke
        generateStyleCode(renderer, cmd.lineStyle, doc.palette, false)
        renderer.line(fmt("ctx.lineWidth = {cmd.lineWidth};"))
        for rect in cmd.rectangles:
          renderer.line(fmt("ctx.strokeRect({rect.x}, {rect.y}, {rect.width}, {rect.height});"))
        renderer.line("")
      
      of draw_lines:
        # Draw lines
        renderer.line("// Draw lines")
        generateStyleCode(renderer, cmd.lineStyle, doc.palette, false)
        renderer.line(fmt("ctx.lineWidth = {cmd.lineWidth};"))
        renderer.line("ctx.beginPath();")
        for line in cmd.lines:
          renderer.line(fmt("ctx.moveTo({line.start.x}, {line.start.y});"))
          renderer.line(fmt("ctx.lineTo({line.endPoint.x}, {line.endPoint.y});"))
        renderer.line("ctx.stroke();")
        renderer.line("")
      
      of draw_line_loop:
        # Draw line loop
        if cmd.points.len > 0:
          renderer.line("// Draw line loop")
          generateStyleCode(renderer, cmd.lineStyle, doc.palette, false)
          renderer.line(fmt("ctx.lineWidth = {cmd.lineWidth};"))
          renderer.line("ctx.beginPath();")
          renderer.line(fmt("ctx.moveTo({cmd.points[0].x}, {cmd.points[0].y});"))
          for i in 1..<cmd.points.len:
            renderer.line(fmt("ctx.lineTo({cmd.points[i].x}, {cmd.points[i].y});"))
          renderer.line("ctx.closePath();")
          renderer.line("ctx.stroke();")
          renderer.line("")
      
      of draw_line_strip:
        # Draw line strip
        if cmd.points.len > 0:
          renderer.line("// Draw line strip")
          generateStyleCode(renderer, cmd.lineStyle, doc.palette, false)
          renderer.line(fmt("ctx.lineWidth = {cmd.lineWidth};"))
          renderer.line("ctx.beginPath();")
          renderer.line(fmt("ctx.moveTo({cmd.points[0].x}, {cmd.points[0].y});"))
          for i in 1..<cmd.points.len:
            renderer.line(fmt("ctx.lineTo({cmd.points[i].x}, {cmd.points[i].y});"))
          renderer.line("ctx.stroke();")
          renderer.line("")
      
      of fill_polygon:
        # Fill polygon
        if cmd.points.len > 2:
          renderer.line("// Fill polygon")
          generateStyleCode(renderer, cmd.fillStyle, doc.palette, true)
          renderer.line("ctx.beginPath();")
          renderer.line(fmt("ctx.moveTo({cmd.points[0].x}, {cmd.points[0].y});"))
          for i in 1..<cmd.points.len:
            renderer.line(fmt("ctx.lineTo({cmd.points[i].x}, {cmd.points[i].y});"))
          renderer.line("ctx.closePath();")
          renderer.line("ctx.fill();")
          renderer.line("")
      
      of outline_fill_polygon:
        # Outline fill polygon
        if cmd.points.len > 2:
          renderer.line("// Outline fill polygon")
          renderer.line("ctx.beginPath();")
          renderer.line(fmt("ctx.moveTo({cmd.points[0].x}, {cmd.points[0].y});"))
          for i in 1..<cmd.points.len:
            renderer.line(fmt("ctx.lineTo({cmd.points[i].x}, {cmd.points[i].y});"))
          renderer.line("ctx.closePath();")
          # Fill
          generateStyleCode(renderer, cmd.fillStyle, doc.palette, true)
          renderer.line("ctx.fill();")
          # Stroke
          generateStyleCode(renderer, cmd.lineStyle, doc.palette, false)
          renderer.line(fmt("ctx.lineWidth = {cmd.lineWidth};"))
          renderer.line("ctx.stroke();")
          renderer.line("")
      
      of draw_line_path, fill_path, outline_fill_path:
        # Path commands
        renderer.line("// Path command")
        renderer.line("ctx.beginPath();")
        renderer.line(fmt("var curX = {cmd.startPoint.x};"))
        renderer.line(fmt("var curY = {cmd.startPoint.y};"))
        renderer.line("ctx.moveTo(curX, curY);")
        
        for node in cmd.pathNodes:
          generatePathNodeCode(renderer, node)
        
        # Apply fill/stroke based on command type
        if cmd.kind in [fill_path, outline_fill_path]:
          generateStyleCode(renderer, cmd.fillStyle, doc.palette, true)
          # Use evenodd fill rule for paths with merged subpaths
          renderer.line("ctx.fillRule = 'evenodd';")
          renderer.line("ctx.fill();")
          renderer.line("ctx.fillRule = 'nonzero';")
        
        if cmd.kind in [draw_line_path, outline_fill_path]:
          generateStyleCode(renderer, cmd.lineStyle, doc.palette, false)
          renderer.line(fmt("ctx.lineWidth = {cmd.lineWidth};"))
          renderer.line("ctx.stroke();")
        
        renderer.line("")
      
      of text_hint:
        # Text hint (render as text)
        renderer.line("// Text hint")
        renderer.line("ctx.save();")
        renderer.line(fmt("ctx.translate({cmd.centerX}, {cmd.centerY});"))
        renderer.line(fmt("ctx.rotate({cmd.rotation});"))
        renderer.line(fmt("ctx.font = '{cmd.height}px sans-serif';"))
        renderer.line("ctx.textAlign = 'center';")
        renderer.line("ctx.textBaseline = 'middle';")
        # Escape the content string for JavaScript
        let escapedContent = escapeJSString(cmd.content)
        renderer.line(fmt("ctx.fillText('{escapedContent}', 0, 0);"))
        renderer.line("ctx.restore();")
        renderer.line("")

proc renderToCanvas*(doc: TinyVGDocument): string =
  ## Render a TinyVG document to JavaScript canvas code
  var renderer = initCanvasRenderer(
    int(doc.header.width),
    int(doc.header.height),
    float(doc.header.scale)
  )
  
  # Canvas setup
  renderer.line("// TinyVG Canvas Rendering")
  
  # Add arc rendering helper function
  renderer.line("// SVG Arc to Canvas Bezier helper")
  renderer.line("function renderArc(ctx, x0, y0, rx, ry, phi, largeArc, sweep, x, y) {")
  renderer.incIndent()
  renderer.line("// Convert SVG arc to canvas bezier curves")
  renderer.line("if (rx === 0 || ry === 0) {")
  renderer.incIndent()
  renderer.line("ctx.lineTo(x, y);")
  renderer.line("return;")
  renderer.decIndent()
  renderer.line("}")
  renderer.line("// Ensure radii are positive")
  renderer.line("rx = Math.abs(rx); ry = Math.abs(ry);")
  renderer.line("// Convert rotation to radians")
  renderer.line("var phiRad = phi * Math.PI / 180;")
  renderer.line("var cosPhi = Math.cos(phiRad);")
  renderer.line("var sinPhi = Math.sin(phiRad);")
  renderer.line("// Step 1: Compute (x1', y1')")
  renderer.line("var dx = (x0 - x) / 2;")
  renderer.line("var dy = (y0 - y) / 2;")
  renderer.line("var x1p = cosPhi * dx + sinPhi * dy;")
  renderer.line("var y1p = -sinPhi * dx + cosPhi * dy;")
  renderer.line("// Step 2: Compute (cx', cy')")
  renderer.line("var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);")
  renderer.line("if (lambda > 1) {")
  renderer.incIndent()
  renderer.line("var sqrtLambda = Math.sqrt(lambda);")
  renderer.line("rx *= sqrtLambda;")
  renderer.line("ry *= sqrtLambda;")
  renderer.decIndent()
  renderer.line("}")
  renderer.line("var factor = Math.sqrt(Math.max(0, (rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p) / (rx * rx * y1p * y1p + ry * ry * x1p * x1p)));")
  renderer.line("if (largeArc === sweep) factor = -factor;")
  renderer.line("var cxp = factor * rx * y1p / ry;")
  renderer.line("var cyp = -factor * ry * x1p / rx;")
  renderer.line("// Step 3: Compute (cx, cy)")
  renderer.line("var cx = cosPhi * cxp - sinPhi * cyp + (x0 + x) / 2;")
  renderer.line("var cy = sinPhi * cxp + cosPhi * cyp + (y0 + y) / 2;")
  renderer.line("// Step 4: Compute start and sweep angles")
  renderer.line("var theta1 = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);")
  renderer.line("var theta2 = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx);")
  renderer.line("var deltaTheta = theta2 - theta1;")
  renderer.line("if (!sweep && deltaTheta > 0) deltaTheta -= 2 * Math.PI;")
  renderer.line("if (sweep && deltaTheta < 0) deltaTheta += 2 * Math.PI;")
  renderer.line("// Approximate with bezier curves")
  renderer.line("var segments = Math.ceil(Math.abs(deltaTheta) / (Math.PI / 2));")
  renderer.line("segments = Math.max(1, segments);")
  renderer.line("var eta1 = theta1;")
  renderer.line("var cosEta = Math.cos(eta1);")
  renderer.line("var sinEta = Math.sin(eta1);")
  renderer.line("var epX = cosPhi * rx * cosEta - sinPhi * ry * sinEta + cx;")
  renderer.line("var epY = sinPhi * rx * cosEta + cosPhi * ry * sinEta + cy;")
  renderer.line("var alpha = Math.sin(Math.abs(deltaTheta) / segments / 2) * 4 / 3;")
  renderer.line("for (var i = 0; i < segments; i++) {")
  renderer.incIndent()
  renderer.line("var eta2 = eta1 + deltaTheta / segments;")
  renderer.line("var cosEta2 = Math.cos(eta2);")
  renderer.line("var sinEta2 = Math.sin(eta2);")
  renderer.line("var epX2 = cosPhi * rx * cosEta2 - sinPhi * ry * sinEta2 + cx;")
  renderer.line("var epY2 = sinPhi * rx * cosEta2 + cosPhi * ry * sinEta2 + cy;")
  renderer.line("var dX = -cosPhi * rx * sinEta - sinPhi * ry * cosEta;")
  renderer.line("var dY = -sinPhi * rx * sinEta + cosPhi * ry * cosEta;")
  renderer.line("var cp1x = epX + alpha * dX;")
  renderer.line("var cp1y = epY + alpha * dY;")
  renderer.line("dX = -cosPhi * rx * sinEta2 - sinPhi * ry * cosEta2;")
  renderer.line("dY = -sinPhi * rx * sinEta2 + cosPhi * ry * cosEta2;")
  renderer.line("var cp2x = epX2 - alpha * dX;")
  renderer.line("var cp2y = epY2 - alpha * dY;")
  renderer.line("ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, epX2, epY2);")
  renderer.line("eta1 = eta2;")
  renderer.line("cosEta = cosEta2;")
  renderer.line("sinEta = sinEta2;")
  renderer.line("epX = epX2;")
  renderer.line("epY = epY2;")
  renderer.decIndent()
  renderer.line("}")
  renderer.decIndent()
  renderer.line("}")
  renderer.line("")
  
  renderer.line("var canvas = document.getElementById('tinyvg-canvas');")
  renderer.line("var ctx = null;")
  renderer.line("if (canvas) {")
  renderer.incIndent()
  renderer.line("ctx = canvas.getContext('2d');")
  renderer.decIndent()
  renderer.line("}")
  renderer.line("if (ctx) {")
  renderer.incIndent()
  
  # Generate render commands
  generateRenderCommands(doc, "ctx", renderer)
  
  renderer.decIndent()
  renderer.line("} else {")
  renderer.incIndent()
  renderer.line("console.error('Could not initialize canvas context');")
  renderer.decIndent()
  renderer.line("}")
  
  # Get the result
  renderer.stream.setPosition(0)
  result = renderer.stream.readAll()
  renderer.stream.close()

proc renderToCanvasCommands*(doc: TinyVGDocument; ctxName: string = "ctx"): string =
  ## Render only the drawing commands without canvas setup
  ## Useful when integrating into existing canvas code
  var renderer = initCanvasRenderer(
    int(doc.header.width),
    int(doc.header.height),
    float(doc.header.scale)
  )
  
  generateRenderCommands(doc, ctxName, renderer)
  
  # Get the result
  renderer.stream.setPosition(0)
  result = renderer.stream.readAll()
  renderer.stream.close()

proc renderToCanvasHTML*(doc: TinyVGDocument): string =
  ## Render a TinyVG document to a complete HTML file with canvas
  var renderer = initCanvasRenderer(
    int(doc.header.width),
    int(doc.header.height),
    float(doc.header.scale)
  )
  
  renderer.line("<!DOCTYPE html>")
  renderer.line("<html>")
  renderer.line("<head>")
  renderer.incIndent()
  renderer.line("<meta charset=\"UTF-8\">")
  renderer.line(fmt("<title>TinyVG Rendering ({doc.header.width}x{doc.header.height})</title>"))
  renderer.line("<style>")
  renderer.incIndent()
  renderer.line("body { margin: 0; padding: 20px; font-family: sans-serif; }")
  renderer.line("canvas { border: 1px solid #ccc; }")
  renderer.decIndent()
  renderer.line("</style>")
  renderer.decIndent()
  renderer.line("</head>")
  renderer.line("<body>")
  renderer.incIndent()
  renderer.line(fmt("<canvas id=\"tinyvg-canvas\" width=\"{doc.header.width}\" height=\"{doc.header.height}\"></canvas>"))
  renderer.line("<script>")
  renderer.incIndent()
  
  # Generate the render code
  generateRenderCommands(doc, "ctx", renderer)
  
  renderer.decIndent()
  renderer.line("</script>")
  renderer.decIndent()
  renderer.line("</body>")
  renderer.line("</html>")
  
  # Get the result
  renderer.stream.setPosition(0)
  result = renderer.stream.readAll()
  renderer.stream.close()
