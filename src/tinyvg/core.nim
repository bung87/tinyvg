# TinyVG core types and structures - Memory Optimized
#
# Memory optimizations applied:
# - Use float32 instead of float (50% reduction for FP values, 8->4 bytes each)
# - Use smaller integer types (int32/int16 instead of int)
# - Pre-allocate sequences with capacity hints
# - Remove unused imports

import strutils

# Type aliases for optimized types
type
  VGFloat* = float32  ## 4 bytes instead of 8
  VGInt* = int32      ## 4 bytes, consistent size across platforms
  VGShort* = int16    ## 2 bytes for small integers
  VGByte* = uint8     ## 1 byte for tiny values

# TinyVG header structure - optimized
type
  TinyVGVersion* = VGByte
  TinyVGWidth* = VGShort
  TinyVGHeight* = VGShort
  TinyVGScale* = VGFloat
  TinyVGFormat* = enum
    u8888 = 0'u8  # 32-bit RGBA
    u888 = 1'u8   # 24-bit RGB
  TinyVGPrecision* = enum
    default = 0'u8

  TinyVGHeader* = object
    version*: TinyVGVersion    # 1 byte
    width*: TinyVGWidth        # 2 bytes
    height*: TinyVGHeight      # 2 bytes
    scale*: TinyVGScale        # 4 bytes
    format*: TinyVGFormat      # 1 byte
    precision*: TinyVGPrecision # 1 byte
    # Total: ~11 bytes (was ~40+ bytes with int/float)

# Color types - optimized to use float32
type
  TinyVGColor* = object
    r*: VGFloat  # 4 bytes, 0.0-1.0
    g*: VGFloat  # 4 bytes
    b*: VGFloat  # 4 bytes
    a*: VGFloat  # 4 bytes (optional, default 1.0)
    # Total: 16 bytes (was 32 bytes with float64)

  TinyVGColorPalette* = seq[TinyVGColor]

# Point and coordinate types
type
  VGPoint* = tuple[x, y: VGFloat]           # 8 bytes
  VGRectangle* = tuple[x, y, width, height: VGFloat]  # 16 bytes
  VGLine* = tuple[start, endPoint: VGPoint] # 16 bytes
  VGGlyph* = tuple[startOffset, endOffset: VGInt]     # 8 bytes

# Style types
type
  TinyVGStyleKind* = enum
    flat = 0'u8
    linear = 1'u8
    radial = 2'u8

  TinyVGStyle* = object
    case kind*: TinyVGStyleKind
    of flat:
      flatColorIndex*: VGInt  # 4 bytes instead of 8
    of linear:
      linearStartPoint*: VGPoint      # 8 bytes
      linearEndPoint*: VGPoint        # 8 bytes
      linearStartColorIndex*: VGInt   # 4 bytes
      linearEndColorIndex*: VGInt     # 4 bytes
    of radial:
      radialStartPoint*: VGPoint      # 8 bytes
      radialEndPoint*: VGPoint        # 8 bytes
      radialStartColorIndex*: VGInt   # 4 bytes
      radialEndColorIndex*: VGInt     # 4 bytes

# Path node types
type
  TinyVGPathNodeKind* = enum
    horiz = 0'u8
    vert = 1'u8
    line = 2'u8
    bezier = 3'u8
    quadratic_bezier = 4'u8
    arc_ellipse = 5'u8
    arc_circle = 6'u8
    close = 7'u8

  TinyVGPathNode* = object
    lineWidthChange*: VGFloat  # 4 bytes
    case kind*: TinyVGPathNodeKind  # 1 byte + padding
    of horiz:
      horizX*: VGFloat           # 4 bytes
    of vert:
      vertY*: VGFloat            # 4 bytes
    of line:
      lineX*: VGFloat            # 4 bytes
      lineY*: VGFloat            # 4 bytes
    of bezier:
      bezierControl1*: VGPoint   # 8 bytes
      bezierControl2*: VGPoint   # 8 bytes
      bezierEndPoint*: VGPoint   # 8 bytes
    of quadratic_bezier:
      quadControl*: VGPoint      # 8 bytes
      quadEndPoint*: VGPoint     # 8 bytes
    of arc_ellipse:
      arcRadiusX*: VGFloat       # 4 bytes
      arcRadiusY*: VGFloat       # 4 bytes
      arcAngle*: VGFloat         # 4 bytes
      arcLargeArc*: bool         # 1 byte
      arcSweep*: bool            # 1 byte
      arcEndPoint*: VGPoint      # 8 bytes
    of arc_circle:
      circleRadius*: VGFloat     # 4 bytes
      circleLargeArc*: bool      # 1 byte
      circleSweep*: bool         # 1 byte
      circleEndPoint*: VGPoint   # 8 bytes
    of close:
      discard

# Drawing command types
type
  TinyVGCommandKind* = enum
    fill_rectangles = 0'u8
    outline_fill_rectangles = 1'u8
    draw_lines = 2'u8
    draw_line_loop = 3'u8
    draw_line_strip = 4'u8
    fill_polygon = 5'u8
    outline_fill_polygon = 6'u8
    draw_line_path = 7'u8
    fill_path = 8'u8
    outline_fill_path = 9'u8
    text_hint = 10'u8

  TinyVGCommand* = object
    kind*: TinyVGCommandKind
    # Common fields
    fillStyle*: TinyVGStyle
    lineStyle*: TinyVGStyle
    lineWidth*: VGFloat
    rectangles*: seq[VGRectangle]
    lines*: seq[VGLine]
    points*: seq[VGPoint]
    startPoint*: VGPoint
    pathNodes*: seq[TinyVGPathNode]
    centerX*: VGFloat
    centerY*: VGFloat
    rotation*: VGFloat
    height*: VGFloat
    content*: string  # Kept as string for text content
    glyphs*: seq[VGGlyph]

# Main TinyVG document structure
type
  TinyVGDocument* = object
    header*: TinyVGHeader
    palette*: TinyVGColorPalette
    commands*: seq[TinyVGCommand]

# Memory statistics helper
type
  MemoryStats* = object
    headerSize*: int
    colorSize*: int
    pointSize*: int
    rectangleSize*: int
    lineSize*: int
    styleSize*: int
    pathNodeSize*: int
    commandBaseSize*: int
    documentOverhead*: int

proc getMemoryStats*(): MemoryStats =
  ## Get memory usage statistics for TinyVG types
  result.headerSize = sizeof(TinyVGHeader)
  result.colorSize = sizeof(TinyVGColor)
  result.pointSize = sizeof(VGPoint)
  result.rectangleSize = sizeof(VGRectangle)
  result.lineSize = sizeof(VGLine)
  result.styleSize = sizeof(TinyVGStyle)
  result.pathNodeSize = sizeof(TinyVGPathNode)
  result.commandBaseSize = sizeof(TinyVGCommand)
  result.documentOverhead = sizeof(TinyVGDocument)

proc formatMemoryStats*(stats: MemoryStats): string =
  ## Format memory stats as string
  result = "TinyVG Memory Statistics:\n"
  result.add "  TinyVGHeader:      " & $stats.headerSize & " bytes\n"
  result.add "  TinyVGColor:       " & $stats.colorSize & " bytes\n"
  result.add "  VGPoint:           " & $stats.pointSize & " bytes\n"
  result.add "  VGRectangle:       " & $stats.rectangleSize & " bytes\n"
  result.add "  VGLine:            " & $stats.lineSize & " bytes\n"
  result.add "  TinyVGStyle:       " & $stats.styleSize & " bytes (max)\n"
  result.add "  TinyVGPathNode:    " & $stats.pathNodeSize & " bytes (max)\n"
  result.add "  TinyVGCommand:     " & $stats.commandBaseSize & " bytes (base)\n"
  result.add "  TinyVGDocument:    " & $stats.documentOverhead & " bytes (overhead)"

# Memory usage estimation
proc estimateMemoryUsage*(doc: TinyVGDocument): int =
  ## Estimate total memory usage of a document in bytes
  result = sizeof(TinyVGDocument)
  result += doc.palette.len * sizeof(TinyVGColor)
  result += doc.commands.len * sizeof(TinyVGCommand)

  for cmd in doc.commands:
    result += cmd.rectangles.len * sizeof(VGRectangle)
    result += cmd.lines.len * sizeof(VGLine)
    result += cmd.points.len * sizeof(VGPoint)
    result += cmd.pathNodes.len * sizeof(TinyVGPathNode)
    result += cmd.glyphs.len * sizeof(VGGlyph)
    result += cmd.content.len  # String content

proc formatMemoryEstimate*(doc: TinyVGDocument): string =
  ## Format memory estimate for a document
  let bytes = estimateMemoryUsage(doc)
  let kb = bytes.float / 1024.0
  result = "Document Memory Usage:\n"
  result.add "  Total: " & $bytes & " bytes (" & $(kb).formatFloat(ffDecimal, 2) & " KB)\n"
  result.add "  Header: " & $sizeof(TinyVGHeader) & " bytes\n"
  result.add "  Palette: " & $doc.palette.len & " colors (" & $(doc.palette.len * sizeof(TinyVGColor)) & " bytes)\n"
  result.add "  Commands: " & $doc.commands.len & " commands\n"

# Helper functions with capacity hints
func initTinyVGDocument*(width, height: int; scale: VGFloat = 1.0; format: TinyVGFormat = u8888;
                         initialPaletteCapacity: int = 16; initialCommandCapacity: int = 32): TinyVGDocument =
  ## Initialize a new TinyVG document with capacity hints
  result = TinyVGDocument(
    header: TinyVGHeader(
      version: 1,
      width: VGShort(width),
      height: VGShort(height),
      scale: scale,
      format: format,
      precision: default
    )
  )
  # Pre-allocate with capacity hints to reduce reallocations
  result.palette = newSeqOfCap[TinyVGColor](initialPaletteCapacity)
  result.commands = newSeqOfCap[TinyVGCommand](initialCommandCapacity)

func addColor*(doc: var TinyVGDocument; r, g, b: VGFloat; a: VGFloat = 1.0): VGInt =
  ## Add a color to the palette and return its index
  doc.palette.add(TinyVGColor(r: r, g: g, b: b, a: a))
  result = VGInt(doc.palette.len - 1)

func createLinearGradientStyle*(startPoint, endPoint: VGPoint; startColorIndex, endColorIndex: VGInt): TinyVGStyle =
  ## Create a linear gradient style
  result = TinyVGStyle(
    kind: linear,
    linearStartPoint: startPoint,
    linearEndPoint: endPoint,
    linearStartColorIndex: startColorIndex,
    linearEndColorIndex: endColorIndex
  )

func createRadialGradientStyle*(startPoint, endPoint: VGPoint; startColorIndex, endColorIndex: VGInt): TinyVGStyle =
  ## Create a radial gradient style
  result = TinyVGStyle(
    kind: radial,
    radialStartPoint: startPoint,
    radialEndPoint: endPoint,
    radialStartColorIndex: startColorIndex,
    radialEndColorIndex: endColorIndex
  )

func addFillRectangle*(doc: var TinyVGDocument; x, y, width, height: VGFloat; style: TinyVGStyle) =
  ## Add a filled rectangle command with any style (flat or gradient)
  var cmd = TinyVGCommand(
    kind: fill_rectangles,
    fillStyle: style
  )
  cmd.rectangles = newSeqOfCap[VGRectangle](1)
  cmd.rectangles.add((x, y, width, height))
  doc.commands.add(cmd)

func addFillRectangle*(doc: var TinyVGDocument; x, y, width, height: VGFloat; colorIndex: VGInt) =
  ## Add a filled rectangle command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addFillRectangle(doc, x, y, width, height, style)

func addOutlineFillRectangle*(doc: var TinyVGDocument; x, y, width, height: VGFloat;
                              fillStyle, lineStyle: TinyVGStyle; lineWidth: VGFloat) =
  ## Add an outlined filled rectangle command with any styles
  var cmd = TinyVGCommand(
    kind: outline_fill_rectangles,
    fillStyle: fillStyle,
    lineStyle: lineStyle,
    lineWidth: lineWidth
  )
  cmd.rectangles = newSeqOfCap[VGRectangle](1)
  cmd.rectangles.add((x, y, width, height))
  doc.commands.add(cmd)

func addOutlineFillRectangle*(doc: var TinyVGDocument; x, y, width, height: VGFloat;
                              fillColorIndex, lineColorIndex: VGInt; lineWidth: VGFloat) =
  ## Add an outlined filled rectangle command with flat colors (convenience overload)
  let fillStyle = TinyVGStyle(kind: flat, flatColorIndex: fillColorIndex)
  let lineStyle = TinyVGStyle(kind: flat, flatColorIndex: lineColorIndex)
  addOutlineFillRectangle(doc, x, y, width, height, fillStyle, lineStyle, lineWidth)

# Additional drawing command helpers

func addDrawLines*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; style: TinyVGStyle; lineWidth: VGFloat) =
  ## Add a draw lines command (individual line segments) with any style
  if points.len < 2:
    return
  var cmd = TinyVGCommand(
    kind: draw_lines,
    lineStyle: style,
    lineWidth: lineWidth
  )
  cmd.lines = newSeqOfCap[VGLine](points.len div 2)
  for i in 0..<points.len div 2:
    let start = VGPoint(points[i * 2])
    let endPoint = VGPoint(points[i * 2 + 1])
    cmd.lines.add((start, endPoint))
  doc.commands.add(cmd)

func addDrawLines*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; colorIndex: VGInt; lineWidth: VGFloat) =
  ## Add a draw lines command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addDrawLines(doc, points, style, lineWidth)

func addDrawLineLoop*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; style: TinyVGStyle; lineWidth: VGFloat) =
  ## Add a draw line loop command (connected lines forming a closed shape) with any style
  if points.len < 2:
    return
  var cmd = TinyVGCommand(
    kind: draw_line_loop,
    lineStyle: style,
    lineWidth: lineWidth
  )
  cmd.points = newSeqOfCap[VGPoint](points.len)
  for p in points:
    cmd.points.add(VGPoint(p))
  doc.commands.add(cmd)

func addDrawLineLoop*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; colorIndex: VGInt; lineWidth: VGFloat) =
  ## Add a draw line loop command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addDrawLineLoop(doc, points, style, lineWidth)

func addDrawLineStrip*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; style: TinyVGStyle; lineWidth: VGFloat) =
  ## Add a draw line strip command (connected lines) with any style
  if points.len < 2:
    return
  var cmd = TinyVGCommand(
    kind: draw_line_strip,
    lineStyle: style,
    lineWidth: lineWidth
  )
  cmd.points = newSeqOfCap[VGPoint](points.len)
  for p in points:
    cmd.points.add(VGPoint(p))
  doc.commands.add(cmd)

func addDrawLineStrip*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; colorIndex: VGInt; lineWidth: VGFloat) =
  ## Add a draw line strip command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addDrawLineStrip(doc, points, style, lineWidth)

func addFillPolygon*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; style: TinyVGStyle) =
  ## Add a fill polygon command with any style
  if points.len < 3:
    return
  var cmd = TinyVGCommand(
    kind: fill_polygon,
    fillStyle: style
  )
  cmd.points = newSeqOfCap[VGPoint](points.len)
  for p in points:
    cmd.points.add(VGPoint(p))
  doc.commands.add(cmd)

func addFillPolygon*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; colorIndex: VGInt) =
  ## Add a fill polygon command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addFillPolygon(doc, points, style)

func addOutlineFillPolygon*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; fillStyle, lineStyle: TinyVGStyle; lineWidth: VGFloat) =
  ## Add an outlined fill polygon command with any styles
  if points.len < 3:
    return
  var cmd = TinyVGCommand(
    kind: outline_fill_polygon,
    fillStyle: fillStyle,
    lineStyle: lineStyle,
    lineWidth: lineWidth
  )
  cmd.points = newSeqOfCap[VGPoint](points.len)
  for p in points:
    cmd.points.add(VGPoint(p))
  doc.commands.add(cmd)

func addOutlineFillPolygon*(doc: var TinyVGDocument; points: openArray[tuple[x, y: VGFloat]]; fillColorIndex, lineColorIndex: VGInt; lineWidth: VGFloat) =
  ## Add an outlined fill polygon command with flat colors (convenience overload)
  let fillStyle = TinyVGStyle(kind: flat, flatColorIndex: fillColorIndex)
  let lineStyle = TinyVGStyle(kind: flat, flatColorIndex: lineColorIndex)
  addOutlineFillPolygon(doc, points, fillStyle, lineStyle, lineWidth)

# Path-based drawing helpers

func addDrawLinePath*(doc: var TinyVGDocument; startPoint: tuple[x, y: VGFloat]; pathNodes: openArray[TinyVGPathNode]; style: TinyVGStyle; lineWidth: VGFloat) =
  ## Add a draw line path command with any style
  var cmd = TinyVGCommand(
    kind: draw_line_path,
    lineStyle: style,
    lineWidth: lineWidth,
    startPoint: VGPoint(startPoint)
  )
  cmd.pathNodes = newSeqOfCap[TinyVGPathNode](pathNodes.len)
  for node in pathNodes:
    cmd.pathNodes.add(node)
  doc.commands.add(cmd)

func addDrawLinePath*(doc: var TinyVGDocument; startPoint: tuple[x, y: VGFloat]; pathNodes: openArray[TinyVGPathNode]; colorIndex: VGInt; lineWidth: VGFloat) =
  ## Add a draw line path command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addDrawLinePath(doc, startPoint, pathNodes, style, lineWidth)

func addFillPath*(doc: var TinyVGDocument; startPoint: tuple[x, y: VGFloat]; pathNodes: openArray[TinyVGPathNode]; style: TinyVGStyle) =
  ## Add a fill path command with any style
  var cmd = TinyVGCommand(
    kind: fill_path,
    fillStyle: style,
    startPoint: VGPoint(startPoint)
  )
  cmd.pathNodes = newSeqOfCap[TinyVGPathNode](pathNodes.len)
  for node in pathNodes:
    cmd.pathNodes.add(node)
  doc.commands.add(cmd)

func addFillPath*(doc: var TinyVGDocument; startPoint: tuple[x, y: VGFloat]; pathNodes: openArray[TinyVGPathNode]; colorIndex: VGInt) =
  ## Add a fill path command with flat color (convenience overload)
  let style = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
  addFillPath(doc, startPoint, pathNodes, style)

func addOutlineFillPath*(doc: var TinyVGDocument; startPoint: tuple[x, y: VGFloat]; pathNodes: openArray[TinyVGPathNode]; fillStyle, lineStyle: TinyVGStyle; lineWidth: VGFloat) =
  ## Add an outlined fill path command with any styles
  var cmd = TinyVGCommand(
    kind: outline_fill_path,
    fillStyle: fillStyle,
    lineStyle: lineStyle,
    lineWidth: lineWidth,
    startPoint: VGPoint(startPoint)
  )
  cmd.pathNodes = newSeqOfCap[TinyVGPathNode](pathNodes.len)
  for node in pathNodes:
    cmd.pathNodes.add(node)
  doc.commands.add(cmd)

func addOutlineFillPath*(doc: var TinyVGDocument; startPoint: tuple[x, y: VGFloat]; pathNodes: openArray[TinyVGPathNode]; fillColorIndex, lineColorIndex: VGInt; lineWidth: VGFloat) =
  ## Add an outlined fill path command with flat colors (convenience overload)
  let fillStyle = TinyVGStyle(kind: flat, flatColorIndex: fillColorIndex)
  let lineStyle = TinyVGStyle(kind: flat, flatColorIndex: lineColorIndex)
  addOutlineFillPath(doc, startPoint, pathNodes, fillStyle, lineStyle, lineWidth)

# Text hint helper

func addTextHint*(doc: var TinyVGDocument; x, y: VGFloat; rotation: VGFloat; height: VGFloat; content: sink string; glyphs: openArray[tuple[startOffset, endOffset: int]]) =
  ## Add a text hint command
  ## Note: `content` is passed as `sink` to allow move semantics
  var cmd = TinyVGCommand(
    kind: text_hint,
    centerX: x,
    centerY: y,
    rotation: rotation,
    height: height,
    content: content  # Move if possible due to sink
  )
  cmd.glyphs = newSeqOfCap[VGGlyph](glyphs.len)
  for g in glyphs:
    cmd.glyphs.add((VGInt(g.startOffset), VGInt(g.endOffset)))
  doc.commands.add(cmd)

# Path node creation helpers

func newPathLine*(x, y: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a line path node
  result = TinyVGPathNode(kind: line, lineWidthChange: lineWidthChange, lineX: x, lineY: y)

func newPathHoriz*(x: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a horizontal line path node
  result = TinyVGPathNode(kind: horiz, lineWidthChange: lineWidthChange, horizX: x)

func newPathVert*(y: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a vertical line path node
  result = TinyVGPathNode(kind: vert, lineWidthChange: lineWidthChange, vertY: y)

func newPathBezier*(c1x, c1y, c2x, c2y, endX, endY: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a cubic Bezier path node
  result = TinyVGPathNode(
    kind: bezier,
    lineWidthChange: lineWidthChange,
    bezierControl1: (c1x, c1y),
    bezierControl2: (c2x, c2y),
    bezierEndPoint: (endX, endY)
  )

func newPathQuadraticBezier*(cx, cy, endX, endY: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a quadratic Bezier path node
  result = TinyVGPathNode(
    kind: quadratic_bezier,
    lineWidthChange: lineWidthChange,
    quadControl: (cx, cy),
    quadEndPoint: (endX, endY)
  )

func newPathArcEllipse*(rx, ry, angle: VGFloat; largeArc, sweep: bool; endX, endY: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create an elliptical arc path node
  result = TinyVGPathNode(
    kind: arc_ellipse,
    lineWidthChange: lineWidthChange,
    arcRadiusX: rx,
    arcRadiusY: ry,
    arcAngle: angle,
    arcLargeArc: largeArc,
    arcSweep: sweep,
    arcEndPoint: (endX, endY)
  )

func newPathArcCircle*(r: VGFloat; largeArc, sweep: bool; endX, endY: VGFloat; lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a circular arc path node
  result = TinyVGPathNode(
    kind: arc_circle,
    lineWidthChange: lineWidthChange,
    circleRadius: r,
    circleLargeArc: largeArc,
    circleSweep: sweep,
    circleEndPoint: (endX, endY)
  )

func newPathClose*(lineWidthChange: VGFloat = -1.0): TinyVGPathNode =
  ## Create a close path node
  result = TinyVGPathNode(kind: close, lineWidthChange: lineWidthChange)
