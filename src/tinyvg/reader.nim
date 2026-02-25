# TinyVG reader implementation

import std/[strutils, parseutils, strformat, strscans]
import core

# Custom exception for parsing errors
type
  TinyVGTextParsingError* = object of ValueError

proc parseTinyVG*(text: string): TinyVGDocument =
  ## Parse a TinyVG text format string into a TinyVGDocument
  var lineIndex = 0
  var inHeader = false
  var inPalette = false
  var inCommands = false
  var currentCommand: TinyVGCommand
  var currentPathNodes: seq[TinyVGPathNode]
  var currentPoints: seq[VGPoint]
  var currentRectangles: seq[VGRectangle]
  var currentLines: seq[VGLine]
  var currentGlyphs: seq[VGGlyph]
  var currentStyle: TinyVGStyle
  var currentLineStyle: TinyVGStyle
  var currentLineWidth: VGFloat
  var currentStartPoint: VGPoint
  var currentContent: string

  # Use iterator instead of splitLines to avoid copying
  iterator linesIter(s: string): string =
    var i = 0
    var lineStart = 0
    while i < s.len:
      if s[i] == '\n' or s[i] == '\r':
        yield s[lineStart..<i]
        # Skip \r\n or \n\r
        if i + 1 < s.len and s[i+1] in {'\n', '\r'} and s[i+1] != s[i]:
          i += 2
        else:
          i += 1
        lineStart = i
      else:
        i += 1
    if lineStart < s.len:
      yield s[lineStart..<s.len]

  # Convert iterator to seq for indexed access
  var lines: seq[string] = @[]
  for line in linesIter(text):
    lines.add(line)

  proc nextLine(): string =
    if lineIndex < lines.len:
      result = lines[lineIndex].strip()
      lineIndex += 1
    else:
      result = ""

  proc expectToken(expected: string) =
    var line = nextLine()
    if not line.startswith(expected):
      raise newException(TinyVGTextParsingError, fmt("Expected '{expected}', got '{line}' at line {lineIndex}"))

  proc parseNumber(line: string): VGFloat =
    ## Parse a number, handling fractions like "1/32"
    if line.len == 0:
      raise newException(TinyVGTextParsingError, "Expected number, got empty string")
    
    # Check if it's a fraction like "1/32"
    if '/' in line:
      var parts = line.split('/')
      if parts.len == 2:
        var numerator: float
        var denominator: float
        if parseFloat(parts[0].strip(), numerator) == 0:
          raise newException(TinyVGTextParsingError, fmt("Expected number, got '{line}'"))
        if parseFloat(parts[1].strip(), denominator) == 0:
          raise newException(TinyVGTextParsingError, fmt("Expected number, got '{line}'"))
        if denominator == 0:
          raise newException(TinyVGTextParsingError, fmt("Division by zero in fraction '{line}'"))
        result = VGFloat(numerator / denominator)
      else:
        raise newException(TinyVGTextParsingError, fmt("Invalid fraction format, got '{line}'"))
    else:
      var num: float
      if parseFloat(line, num) == 0:
        raise newException(TinyVGTextParsingError, fmt("Expected number, got '{line}'"))
      result = VGFloat(num)

  proc parseInt(line: string): int =
    if line.len == 0:
      raise newException(TinyVGTextParsingError, "Expected integer, got empty string")
    var num: int
    if parseInt(line, num) == 0:
      raise newException(TinyVGTextParsingError, fmt("Expected integer, got '{line}'"))
    result = num

  proc parsePoint(line: string): VGPoint =
    ## Parse a point in format "(x y)"
    var x, y: float
    # Use strscans for more robust parsing
    if scanf(line, "($f$f)", x, y):
      result = (VGFloat(x), VGFloat(y))
    elif scanf(line, "($f $f)", x, y):
      result = (VGFloat(x), VGFloat(y))
    else:
      # Fallback to manual parsing
      var parts = line.strip(chars={'(', ')', ' '}).split(Whitespace, maxsplit=2)
      if parts.len != 2:
        raise newException(TinyVGTextParsingError, fmt("Expected point (x y), got '{line}'"))
      result = (parseNumber(parts[0]), parseNumber(parts[1]))

  proc parseColor(line: string): TinyVGColor =
    ## Parse a color in format "(r g b)" or "(r g b a)"
    var r, g, b, a: float = 1.0
    # Try RGBA first
    if scanf(line, "($f$f$f$f)", r, g, b, a):
      result = TinyVGColor(r: VGFloat(r), g: VGFloat(g), b: VGFloat(b), a: VGFloat(a))
    elif scanf(line, "($f $f $f $f)", r, g, b, a):
      result = TinyVGColor(r: VGFloat(r), g: VGFloat(g), b: VGFloat(b), a: VGFloat(a))
    elif scanf(line, "($f$f$f)", r, g, b):
      result = TinyVGColor(r: VGFloat(r), g: VGFloat(g), b: VGFloat(b), a: 1.0)
    elif scanf(line, "($f $f $f)", r, g, b):
      result = TinyVGColor(r: VGFloat(r), g: VGFloat(g), b: VGFloat(b), a: 1.0)
    else:
      # Fallback to manual parsing
      var parts = line.strip(chars={'(', ')', ' '}).split(Whitespace)
      if parts.len == 3:
        result = TinyVGColor(r: parseNumber(parts[0]), g: parseNumber(parts[1]), b: parseNumber(parts[2]), a: 1.0)
      elif parts.len == 4:
        result = TinyVGColor(r: parseNumber(parts[0]), g: parseNumber(parts[1]), b: parseNumber(parts[2]), a: parseNumber(parts[3]))
      else:
        raise newException(TinyVGTextParsingError, fmt("Expected color (r g b) or (r g b a), got '{line}'"))

  proc parseStyle(line: string): TinyVGStyle =
    ## Parse a style: "flat N", "linear x1 y1 x2 y2 startIdx endIdx", or "radial x1 y1 x2 y2 startIdx endIdx"
    var parts = line.strip(chars={'(', ')', ' '}).split(Whitespace, maxsplit=1)
    if parts.len == 0:
      raise newException(TinyVGTextParsingError, fmt("Expected style, got empty line"))
    
    let styleType = parts[0]
    
    case styleType
    of "flat":
      if parts.len < 2:
        raise newException(TinyVGTextParsingError, fmt("Expected flat style with color index, got '{line}'"))
      let colorIdx = parseInt(parts[1])
      result = TinyVGStyle(kind: flat, flatColorIndex: VGInt(colorIdx))
    of "linear":
      var rest = parts[1]
      var x1, y1, x2, y2: float
      var startIdx, endIdx: int
      if scanf(rest, "$f$f$f$f$i$i", x1, y1, x2, y2, startIdx, endIdx):
        result = TinyVGStyle(
          kind: linear,
          linearStartPoint: (VGFloat(x1), VGFloat(y1)),
          linearEndPoint: (VGFloat(x2), VGFloat(y2)),
          linearStartColorIndex: VGInt(startIdx),
          linearEndColorIndex: VGInt(endIdx)
        )
      elif scanf(rest, "$f $f $f $f $i $i", x1, y1, x2, y2, startIdx, endIdx):
        result = TinyVGStyle(
          kind: linear,
          linearStartPoint: (VGFloat(x1), VGFloat(y1)),
          linearEndPoint: (VGFloat(x2), VGFloat(y2)),
          linearStartColorIndex: VGInt(startIdx),
          linearEndColorIndex: VGInt(endIdx)
        )
      else:
        raise newException(TinyVGTextParsingError, fmt("Invalid linear gradient format: '{line}'"))
    of "radial":
      var rest = parts[1]
      var x1, y1, x2, y2: float
      var startIdx, endIdx: int
      if scanf(rest, "$f$f$f$f$i$i", x1, y1, x2, y2, startIdx, endIdx):
        result = TinyVGStyle(
          kind: radial,
          radialStartPoint: (VGFloat(x1), VGFloat(y1)),
          radialEndPoint: (VGFloat(x2), VGFloat(y2)),
          radialStartColorIndex: VGInt(startIdx),
          radialEndColorIndex: VGInt(endIdx)
        )
      elif scanf(rest, "$f $f $f $f $i $i", x1, y1, x2, y2, startIdx, endIdx):
        result = TinyVGStyle(
          kind: radial,
          radialStartPoint: (VGFloat(x1), VGFloat(y1)),
          radialEndPoint: (VGFloat(x2), VGFloat(y2)),
          radialStartColorIndex: VGInt(startIdx),
          radialEndColorIndex: VGInt(endIdx)
        )
      else:
        raise newException(TinyVGTextParsingError, fmt("Invalid radial gradient format: '{line}'"))
    else:
      raise newException(TinyVGTextParsingError, fmt("Expected style (flat/linear/radial), got '{line}'"))

  proc parsePathNode(pathNodeStr: string): TinyVGPathNode =
    ## Parse a path node command
    var parts = pathNodeStr.strip(chars={'(', ')', ' '}).split(Whitespace)
    if parts.len == 0:
      raise newException(TinyVGTextParsingError, "Expected path node, got empty string")
    
    var lineWidthChange: VGFloat = -1.0  # -1 means no change
    var nodeKind: string
    var argStart = 0
    
    # Check if second part is "-" (no line width change) or a number
    if parts.len > 1:
      if parts[1] != "-":
        try:
          lineWidthChange = parseNumber(parts[1])
          argStart = 2
        except TinyVGTextParsingError:
          # Second part is not a number, treat it as part of the args
          argStart = 1
      else:
        argStart = 2
    
    nodeKind = parts[0]
    
    template getArg(argIdx: int): string =
      if argIdx < parts.len: parts[argIdx]
      else: raise newException(TinyVGTextParsingError, "Missing argument " & $argIdx & " for path node '" & nodeKind & "'")
    
    case nodeKind
    of "horiz":
      result = TinyVGPathNode(
        kind: horiz,
        lineWidthChange: lineWidthChange,
        horizX: parseNumber(getArg(argStart))
      )
    of "vert":
      result = TinyVGPathNode(
        kind: vert,
        lineWidthChange: lineWidthChange,
        vertY: parseNumber(getArg(argStart))
      )
    of "line":
      result = TinyVGPathNode(
        kind: line,
        lineWidthChange: lineWidthChange,
        lineX: parseNumber(getArg(argStart)),
        lineY: parseNumber(getArg(argStart + 1))
      )
    of "bezier":
      result = TinyVGPathNode(
        kind: bezier,
        lineWidthChange: lineWidthChange,
        bezierControl1: parsePoint(fmt("({getArg(argStart)} {getArg(argStart + 1)})")),
        bezierControl2: parsePoint(fmt("({getArg(argStart + 2)} {getArg(argStart + 3)})")),
        bezierEndPoint: parsePoint(fmt("({getArg(argStart + 4)} {getArg(argStart + 5)})"))
      )
    of "quadratic_bezier":
      result = TinyVGPathNode(
        kind: quadratic_bezier,
        lineWidthChange: lineWidthChange,
        quadControl: parsePoint(fmt("({getArg(argStart)} {getArg(argStart + 1)})")),
        quadEndPoint: parsePoint(fmt("({getArg(argStart + 2)} {getArg(argStart + 3)})"))
      )
    of "arc_ellipse":
      result = TinyVGPathNode(
        kind: arc_ellipse,
        lineWidthChange: lineWidthChange,
        arcRadiusX: parseNumber(getArg(argStart)),
        arcRadiusY: parseNumber(getArg(argStart + 1)),
        arcAngle: parseNumber(getArg(argStart + 2)),
        arcLargeArc: getArg(argStart + 3) == "true",
        arcSweep: getArg(argStart + 4) == "true",
        arcEndPoint: parsePoint(fmt("({getArg(argStart + 5)} {getArg(argStart + 6)})"))
      )
    of "arc_circle":
      result = TinyVGPathNode(
        kind: arc_circle,
        lineWidthChange: lineWidthChange,
        circleRadius: parseNumber(getArg(argStart)),
        circleLargeArc: getArg(argStart + 1) == "true",
        circleSweep: getArg(argStart + 2) == "true",
        circleEndPoint: parsePoint(fmt("({getArg(argStart + 3)} {getArg(argStart + 4)})"))
      )
    of "close":
      result = TinyVGPathNode(kind: close, lineWidthChange: lineWidthChange)
    else:
      raise newException(TinyVGTextParsingError, fmt("Unknown path node kind: '{nodeKind}'"))

  # Start parsing
  var tvgLine = nextLine()
  if not tvgLine.startswith("(tvg"):
    raise newException(TinyVGTextParsingError, fmt("Expected '(tvg', got '{tvgLine}'"))
  
  # Parse version - handle both "(tvg 1" and "(tvg" followed by "1" on next line
  var versionStr: string
  if tvgLine.len > 5:  # (tvg + space + version
    versionStr = tvgLine[5..^1].strip()
  else:
    versionStr = nextLine()
  
  try:
    result.header.version = TinyVGVersion(parseInt(versionStr))
  except ValueError:
    raise newException(TinyVGTextParsingError, fmt("Invalid version number: '{versionStr}'"))
  
  # Parse header
  var headerLine = nextLine()
  var headerParts: seq[string]
  
  if headerLine.startswith("("):
    # Format: "(w h s f p)" on same line, or "(" followed by values on next line
    if headerLine.len > 1:
      # "(w h s f p)" format
      headerParts = headerLine.strip(chars={'(', ')', ' '}).split()
    else:
      # "(" on one line, values on next
      headerLine = nextLine()
      headerParts = headerLine.split()
      expectToken(")")
  else:
    raise newException(TinyVGTextParsingError, fmt("Expected header starting with '(', got '{headerLine}'"))
  
  if headerParts.len != 5:
    raise newException(TinyVGTextParsingError, fmt("Expected header with 5 values (width height scale format precision), got {headerParts.len} values: '{headerLine}'"))
  
  try:
    result.header.width = TinyVGWidth(parseInt(headerParts[0]))
    result.header.height = TinyVGHeight(parseInt(headerParts[1]))
    result.header.scale = parseNumber(headerParts[2])
  except ValueError as e:
    raise newException(TinyVGTextParsingError, fmt("Invalid header dimensions: {e.msg}"))
  
  # Parse format
  case headerParts[3]
  of "u8888":
    result.header.format = u8888
  of "u888":
    result.header.format = u888
  else:
    raise newException(TinyVGTextParsingError, fmt("Unknown color format: '{headerParts[3]}'"))
  
  result.header.precision = default
  
  # Parse palette
  expectToken("(")
  var line = nextLine()
  while line != ")":
    if line != "":
      try:
        result.palette.add(parseColor(line))
      except TinyVGTextParsingError as e:
        raise newException(TinyVGTextParsingError, fmt("Error parsing palette color at line {lineIndex}: {e.msg}"))
    line = nextLine()
  
  # Parse commands
  expectToken("(")
  line = nextLine()
  while line != ")":
    if line == "(":
      # Start of a command
      var commandLine = nextLine()
      var commandParts = commandLine.split(Whitespace, maxsplit=1)
      if commandParts.len == 0:
        raise newException(TinyVGTextParsingError, fmt("Empty command at line {lineIndex}"))
      
      var commandKind = commandParts[0]
      
      try:
        case commandKind
        of "fill_rectangles":
          var fillStyleLine = nextLine()
          currentStyle = parseStyle(fillStyleLine)
          expectToken("(")
          currentRectangles = @[]
          var rectLine = nextLine()
          while rectLine != ")":
            if rectLine != "":
              # Parse rectangle: (x y width height)
              var x, y, w, h: float
              if scanf(rectLine, "($f$f$f$f)", x, y, w, h):
                currentRectangles.add((VGFloat(x), VGFloat(y), VGFloat(w), VGFloat(h)))
              elif scanf(rectLine, "($f $f $f $f)", x, y, w, h):
                currentRectangles.add((VGFloat(x), VGFloat(y), VGFloat(w), VGFloat(h)))
              else:
                var rectParts = rectLine.strip(chars={'(', ')', ' '}).split(Whitespace)
                if rectParts.len != 4:
                  raise newException(TinyVGTextParsingError, fmt("Expected rectangle (x y width height), got '{rectLine}'"))
                currentRectangles.add((parseNumber(rectParts[0]), parseNumber(rectParts[1]), parseNumber(rectParts[2]), parseNumber(rectParts[3])))
            rectLine = nextLine()
          var cmd = TinyVGCommand(
            kind: fill_rectangles,
            fillStyle: currentStyle,
            rectangles: currentRectangles
          )
          result.commands.add(cmd)
        
        of "outline_fill_rectangles":
          var fillStyleLine = nextLine()
          currentStyle = parseStyle(fillStyleLine)
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          expectToken("(")
          currentRectangles = @[]
          var rectLine = nextLine()
          while rectLine != ")":
            if rectLine != "":
              var x, y, w, h: float
              if scanf(rectLine, "($f$f$f$f)", x, y, w, h):
                currentRectangles.add((VGFloat(x), VGFloat(y), VGFloat(w), VGFloat(h)))
              elif scanf(rectLine, "($f $f $f $f)", x, y, w, h):
                currentRectangles.add((VGFloat(x), VGFloat(y), VGFloat(w), VGFloat(h)))
              else:
                var rectParts = rectLine.strip(chars={'(', ')', ' '}).split(Whitespace)
                if rectParts.len != 4:
                  raise newException(TinyVGTextParsingError, fmt("Expected rectangle (x y width height), got '{rectLine}'"))
                currentRectangles.add((parseNumber(rectParts[0]), parseNumber(rectParts[1]), parseNumber(rectParts[2]), parseNumber(rectParts[3])))
            rectLine = nextLine()
          var cmd = TinyVGCommand(
            kind: outline_fill_rectangles,
            fillStyle: currentStyle,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            rectangles: currentRectangles
          )
          result.commands.add(cmd)
        
        of "draw_lines":
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          expectToken("(")
          currentLines = @[]
          var lineLine = nextLine()
          while lineLine != ")":
            if lineLine != "":
              # Format: ((x1 y1) (x2 y2))
              var x1, y1, x2, y2: float
              if scanf(lineLine, "(($f$f)($f$f))", x1, y1, x2, y2):
                currentLines.add(((VGFloat(x1), VGFloat(y1)), (VGFloat(x2), VGFloat(y2))))
              elif scanf(lineLine, "(($f $f) ($f $f))", x1, y1, x2, y2):
                currentLines.add(((VGFloat(x1), VGFloat(y1)), (VGFloat(x2), VGFloat(y2))))
              else:
                var cleaned = lineLine.strip()
                cleaned.removePrefix('(')
                cleaned.removeSuffix(')')
                # Now: (x1 y1) (x2 y2)
                var parts = cleaned.split(") (")
                if parts.len != 2:
                  raise newException(TinyVGTextParsingError, fmt("Expected line ((x1 y1) (x2 y2)), got '{lineLine}'"))
                var start = parsePoint(parts[0] & ")")
                var endPoint = parsePoint("(" & parts[1])
                currentLines.add((start, endPoint))
            lineLine = nextLine()
          var cmd = TinyVGCommand(
            kind: draw_lines,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            lines: currentLines
          )
          result.commands.add(cmd)
        
        of "draw_line_loop":
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          expectToken("(")
          currentPoints = @[]
          var pointLine = nextLine()
          while pointLine != ")":
            if pointLine != "":
              currentPoints.add(parsePoint(pointLine))
            pointLine = nextLine()
          var cmd = TinyVGCommand(
            kind: draw_line_loop,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            points: currentPoints
          )
          result.commands.add(cmd)
        
        of "draw_line_strip":
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          expectToken("(")
          currentPoints = @[]
          var pointLine = nextLine()
          while pointLine != ")":
            if pointLine != "":
              currentPoints.add(parsePoint(pointLine))
            pointLine = nextLine()
          var cmd = TinyVGCommand(
            kind: draw_line_strip,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            points: currentPoints
          )
          result.commands.add(cmd)
        
        of "fill_polygon":
          var fillStyleLine = nextLine()
          currentStyle = parseStyle(fillStyleLine)
          expectToken("(")
          currentPoints = @[]
          var pointLine = nextLine()
          while pointLine != ")":
            if pointLine != "":
              currentPoints.add(parsePoint(pointLine))
            pointLine = nextLine()
          var cmd = TinyVGCommand(
            kind: fill_polygon,
            fillStyle: currentStyle,
            points: currentPoints
          )
          result.commands.add(cmd)
        
        of "outline_fill_polygon":
          var fillStyleLine = nextLine()
          currentStyle = parseStyle(fillStyleLine)
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          expectToken("(")
          currentPoints = @[]
          var pointLine = nextLine()
          while pointLine != ")":
            if pointLine != "":
              currentPoints.add(parsePoint(pointLine))
            pointLine = nextLine()
          var cmd = TinyVGCommand(
            kind: outline_fill_polygon,
            fillStyle: currentStyle,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            points: currentPoints
          )
          result.commands.add(cmd)
        
        of "draw_line_path":
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          var startPointLine = nextLine()
          currentStartPoint = parsePoint(startPointLine)
          expectToken("(")
          currentPathNodes = @[]
          var pathNodeLine = nextLine()
          while pathNodeLine != ")":
            if pathNodeLine != "":
              currentPathNodes.add(parsePathNode(pathNodeLine))
            pathNodeLine = nextLine()
          var cmd = TinyVGCommand(
            kind: draw_line_path,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            startPoint: currentStartPoint,
            pathNodes: currentPathNodes
          )
          result.commands.add(cmd)
        
        of "fill_path":
          var fillStyleLine = nextLine()
          currentStyle = parseStyle(fillStyleLine)
          var startPointLine = nextLine()
          currentStartPoint = parsePoint(startPointLine)
          expectToken("(")
          currentPathNodes = @[]
          var pathNodeLine = nextLine()
          while pathNodeLine != ")":
            if pathNodeLine != "":
              currentPathNodes.add(parsePathNode(pathNodeLine))
            pathNodeLine = nextLine()
          var cmd = TinyVGCommand(
            kind: fill_path,
            fillStyle: currentStyle,
            startPoint: currentStartPoint,
            pathNodes: currentPathNodes
          )
          result.commands.add(cmd)
        
        of "outline_fill_path":
          var fillStyleLine = nextLine()
          currentStyle = parseStyle(fillStyleLine)
          var lineStyleLine = nextLine()
          currentLineStyle = parseStyle(lineStyleLine)
          var lineWidthLine = nextLine()
          currentLineWidth = parseNumber(lineWidthLine)
          var startPointLine = nextLine()
          currentStartPoint = parsePoint(startPointLine)
          expectToken("(")
          currentPathNodes = @[]
          var pathNodeLine = nextLine()
          while pathNodeLine != ")":
            if pathNodeLine != "":
              currentPathNodes.add(parsePathNode(pathNodeLine))
            pathNodeLine = nextLine()
          var cmd = TinyVGCommand(
            kind: outline_fill_path,
            fillStyle: currentStyle,
            lineStyle: currentLineStyle,
            lineWidth: currentLineWidth,
            startPoint: currentStartPoint,
            pathNodes: currentPathNodes
          )
          result.commands.add(cmd)
        
        of "text_hint":
          var centerLine = nextLine()
          var centerParts = centerLine.strip(chars={'(', ')', ' '}).split(Whitespace)
          if centerParts.len < 2:
            raise newException(TinyVGTextParsingError, fmt("Expected center point (x y), got '{centerLine}'"))
          var centerX = parseNumber(centerParts[0])
          var centerY = parseNumber(centerParts[1])
          var rotationLine = nextLine()
          var rotation = parseNumber(rotationLine)
          var heightLine = nextLine()
          var height = parseNumber(heightLine)
          var contentLine = nextLine()
          var content = contentLine.strip(chars={'"', ' '})
          expectToken("(")
          currentGlyphs = @[]
          var glyphLine = nextLine()
          while glyphLine != ")":
            if glyphLine != "":
              var glyphParts = glyphLine.strip(chars={'(', ')', ' '}).split(Whitespace)
              if glyphParts.len != 2:
                raise newException(TinyVGTextParsingError, fmt("Expected glyph (start end), got '{glyphLine}'"))
              currentGlyphs.add((VGInt(parseInt(glyphParts[0])), VGInt(parseInt(glyphParts[1]))))
            glyphLine = nextLine()
          var cmd = TinyVGCommand(
            kind: text_hint,
            centerX: centerX,
            centerY: centerY,
            rotation: rotation,
            height: height,
            content: content,
            glyphs: currentGlyphs
          )
          result.commands.add(cmd)
        
        else:
          raise newException(TinyVGTextParsingError, fmt("Unknown command: '{commandKind}' at line {lineIndex}"))
      except TinyVGTextParsingError:
        raise
      except Exception as e:
        raise newException(TinyVGTextParsingError, fmt("Error parsing command '{commandKind}' at line {lineIndex}: {e.msg}"))
      
      # Expect closing ) for command
      expectToken(")")
    
    line = nextLine()
  
  # Expect closing ) for tvg
  expectToken(")")

proc readTinyVG*(filename: string): TinyVGDocument =
  ## Read a TinyVG file and parse it
  let text = readFile(filename)
  parseTinyVG(text)
