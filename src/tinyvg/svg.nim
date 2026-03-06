# SVG Parser for TinyVG
#
# Extracted and adapted from pixie library (https://github.com/treeform/pixie)
# Licensed under MIT License

import std/[strtabs, strutils, tables, xmlparser, xmltree]
import core

type
  SvgError* = object of CatchableError
    ## Raised if SVG parsing fails

  SvgParser* = object
    ## SVG parser state
    width*: int
    height*: int
    viewBox*: tuple[x, y, width, height: float32]

  SvgGradientKind* = enum
    ## Types of SVG gradients
    svgLinearGradient
    svgRadialGradient

  SvgGradientStop* = object
    ## A color stop in a gradient
    offset*: float32  ## 0.0 to 1.0
    color*: TinyVGColor

  SvgGradient* = object
    ## SVG gradient definition
    id*: string
    case kind*: SvgGradientKind
    of svgLinearGradient:
      x1*, y1*, x2*, y2*: float32
    of svgRadialGradient:
      cx*, cy*, r*, fx*, fy*: float32
    stops*: seq[SvgGradientStop]

  SvgElementKind* = enum
    ## Types of SVG elements
    svgPath
    svgRect
    svgCircle
    svgEllipse
    svgLine
    svgPolyline
    svgPolygon
    svgGroup
    svgUnknown

  SvgElement* = object
    ## Parsed SVG element
    case kind*: SvgElementKind
    of svgPath:
      d*: string
    of svgRect:
      rectRx*, rectRy*: float32
    of svgCircle:
      r*: float32
    of svgEllipse:
      ellipseRx*, ellipseRy*: float32
    of svgLine:
      x1*, y1*, x2*, y2*: float32
    of svgPolyline, svgPolygon:
      points*: seq[tuple[x, y: float32]]
    of svgGroup:
      children*: seq[SvgElement]
    of svgUnknown:
      discard
    
    # Common attributes
    x*, y*, width*, height*: float32
    fill*: string
    fillSet*: bool  ## True if fill attribute was explicitly set
    stroke*: string
    strokeWidth*: float32
    transform*: string
    opacity*: float32
    hasClipPath*: bool  ## True if element has clip-path attribute (shouldn't render)

  SvgDocument* = object
    ## Parsed SVG document
    width*, height*: int
    viewBox*: tuple[x, y, width, height: float32]
    elements*: seq[SvgElement]
    gradients*: Table[string, SvgGradient]  ## Gradient definitions by ID

template failInvalid(msg: string) =
  raise newException(SvgError, msg)

proc parseFloat32(s: string): float32 =
  ## Parse string to float32
  try:
    result = parseFloat(s).float32
  except ValueError:
    failInvalid("Invalid float value: " & s)

proc parseColor*(colorStr: string): TinyVGColor =
  ## Parse SVG color string to TinyVG color
  if colorStr.len == 0 or colorStr == "none":
    return TinyVGColor(r: 0, g: 0, b: 0, a: 0)
  
  # Handle currentColor keyword (uses current text color, default to black)
  if colorStr.toLowerAscii() == "currentcolor":
    return TinyVGColor(r: 0, g: 0, b: 0, a: 1.0)
  
  # Handle hex colors
  if colorStr.startsWith("#"):
    var hex = colorStr[1..^1]
    if hex.len == 3:
      # Short form #RGB
      let r = parseHexInt($hex[0] & $hex[0]).float32 / 255.0
      let g = parseHexInt($hex[1] & $hex[1]).float32 / 255.0
      let b = parseHexInt($hex[2] & $hex[2]).float32 / 255.0
      return TinyVGColor(r: r, g: g, b: b, a: 1.0)
    elif hex.len == 6:
      # Long form #RRGGBB
      let r = parseHexInt(hex[0..1]).float32 / 255.0
      let g = parseHexInt(hex[2..3]).float32 / 255.0
      let b = parseHexInt(hex[4..5]).float32 / 255.0
      return TinyVGColor(r: r, g: g, b: b, a: 1.0)
  
  # Handle rgb() colors
  if colorStr.startsWith("rgb("):
    let inner = colorStr[4..^2]
    let parts = inner.split(",")
    if parts.len == 3:
      let r = parseFloat(parts[0].strip()).float32 / 255.0
      let g = parseFloat(parts[1].strip()).float32 / 255.0
      let b = parseFloat(parts[2].strip()).float32 / 255.0
      return TinyVGColor(r: r, g: g, b: b, a: 1.0)
  
  # Handle rgba() colors
  if colorStr.startsWith("rgba("):
    let inner = colorStr[5..^2]
    let parts = inner.split(",")
    if parts.len == 4:
      let r = parseFloat(parts[0].strip()).float32 / 255.0
      let g = parseFloat(parts[1].strip()).float32 / 255.0
      let b = parseFloat(parts[2].strip()).float32 / 255.0
      let a = parseFloat(parts[3].strip()).float32
      return TinyVGColor(r: r, g: g, b: b, a: a)
  
  # Handle named colors (basic set)
  case colorStr.toLowerAscii():
    of "black": return TinyVGColor(r: 0, g: 0, b: 0, a: 1.0)
    of "white": return TinyVGColor(r: 1, g: 1, b: 1, a: 1.0)
    of "red": return TinyVGColor(r: 1, g: 0, b: 0, a: 1.0)
    of "green": return TinyVGColor(r: 0, g: 1, b: 0, a: 1.0)
    of "blue": return TinyVGColor(r: 0, g: 0, b: 1, a: 1.0)
    of "yellow": return TinyVGColor(r: 1, g: 1, b: 0, a: 1.0)
    of "cyan": return TinyVGColor(r: 0, g: 1, b: 1, a: 1.0)
    of "magenta": return TinyVGColor(r: 1, g: 0, b: 1, a: 1.0)
    of "gray", "grey": return TinyVGColor(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
    of "orange": return TinyVGColor(r: 1, g: 0.65, b: 0, a: 1.0)
    of "purple": return TinyVGColor(r: 0.5, g: 0, b: 0.5, a: 1.0)
    of "transparent": return TinyVGColor(r: 0, g: 0, b: 0, a: 0)
    else:
      # Default to black for unknown colors
      return TinyVGColor(r: 0, g: 0, b: 0, a: 1.0)

proc parsePoints(pointsStr: string): seq[tuple[x, y: float32]] =
  ## Parse SVG points attribute
  var coords: seq[string]
  
  # Handle both space and comma separated
  if pointsStr.contains(","):
    for pair in pointsStr.splitWhitespace():
      let parts = pair.split(",")
      if parts.len == 2:
        coords.add(parts[0].strip())
        coords.add(parts[1].strip())
  else:
    coords = pointsStr.splitWhitespace()
  
  if coords.len mod 2 != 0:
    failInvalid("Invalid points attribute: odd number of coordinates")
  
  for i in countup(0, coords.len - 1, 2):
    result.add((
      x: parseFloat32(coords[i]),
      y: parseFloat32(coords[i + 1])
    ))

proc attrOrDefault(node: XmlNode, name, default: string): string =
  ## Get attribute value or default
  result = node.attr(name)
  if result.len == 0:
    result = default

proc parseGradientStop(node: XmlNode): SvgGradientStop =
  ## Parse a gradient stop element
  # Handle offset as percentage
  let offsetStr = node.attr("offset")
  if offsetStr.contains("%"):
    result.offset = parseFloat32(offsetStr.replace("%", "")) / 100.0
  else:
    result.offset = parseFloat32(node.attrOrDefault("offset", "0"))
  
  # Parse stop-color attribute
  let stopColor = node.attr("stop-color")
  if stopColor.len > 0:
    result.color = parseColor(stopColor)
  else:
    result.color = TinyVGColor(r: 0, g: 0, b: 0, a: 1.0)
  
  # Handle stop-opacity
  let stopOpacity = parseFloat32(node.attrOrDefault("stop-opacity", "1"))
  result.color.a = stopOpacity

proc parseLinearGradient(node: XmlNode): SvgGradient =
  ## Parse a linearGradient element
  result = SvgGradient(
    kind: svgLinearGradient,
    id: node.attr("id"),
    x1: parseFloat32(node.attrOrDefault("x1", "0")),
    y1: parseFloat32(node.attrOrDefault("y1", "0")),
    x2: parseFloat32(node.attrOrDefault("x2", "1")),
    y2: parseFloat32(node.attrOrDefault("y2", "0"))
  )
  
  # Parse stop elements
  for child in node:
    if child.kind == xnElement and child.tag == "stop":
      result.stops.add(parseGradientStop(child))

proc parseRadialGradient(node: XmlNode): SvgGradient =
  ## Parse a radialGradient element
  result = SvgGradient(
    kind: svgRadialGradient,
    id: node.attr("id"),
    cx: parseFloat32(node.attrOrDefault("cx", "0.5")),
    cy: parseFloat32(node.attrOrDefault("cy", "0.5")),
    r: parseFloat32(node.attrOrDefault("r", "0.5")),
    fx: parseFloat32(node.attrOrDefault("fx", "0.5")),
    fy: parseFloat32(node.attrOrDefault("fy", "0.5"))
  )
  
  # Parse stop elements
  for child in node:
    if child.kind == xnElement and child.tag == "stop":
      result.stops.add(parseGradientStop(child))

type
  InheritedAttrs = object
    ## Attributes that can be inherited from parent elements
    fill: string
    fillSet: bool
    stroke: string
    strokeWidth: float32
    strokeWidthSet: bool

const currentColor* = "currentColor"
  ## SVG keyword for current color

proc parseSvgElement(node: XmlNode, inherit: InheritedAttrs = InheritedAttrs()): SvgElement =
  ## Parse an SVG element from XML node
  ## Inherit attributes from parent element (as per SVG spec)
  if node.kind != xnElement:
    return SvgElement(kind: svgUnknown)
  
  case node.tag:
  of "path":
    result = SvgElement(kind: svgPath)
    result.d = node.attr("d")
  
  of "rect":
    result = SvgElement(kind: svgRect)
    result.x = parseFloat32(node.attrOrDefault("x", "0"))
    result.y = parseFloat32(node.attrOrDefault("y", "0"))
    result.width = parseFloat32(node.attrOrDefault("width", "0"))
    result.height = parseFloat32(node.attrOrDefault("height", "0"))
    result.rectRx = parseFloat32(node.attrOrDefault("rx", "0"))
    result.rectRy = parseFloat32(node.attrOrDefault("ry", "0"))
  
  of "circle":
    result = SvgElement(kind: svgCircle)
    result.x = parseFloat32(node.attrOrDefault("cx", "0"))
    result.y = parseFloat32(node.attrOrDefault("cy", "0"))
    result.r = parseFloat32(node.attr("r"))
  
  of "ellipse":
    result = SvgElement(kind: svgEllipse)
    result.x = parseFloat32(node.attrOrDefault("cx", "0"))
    result.y = parseFloat32(node.attrOrDefault("cy", "0"))
    result.ellipseRx = parseFloat32(node.attr("rx"))
    result.ellipseRy = parseFloat32(node.attr("ry"))
  
  of "line":
    result = SvgElement(kind: svgLine)
    result.x1 = parseFloat32(node.attrOrDefault("x1", "0"))
    result.y1 = parseFloat32(node.attrOrDefault("y1", "0"))
    result.x2 = parseFloat32(node.attrOrDefault("x2", "0"))
    result.y2 = parseFloat32(node.attrOrDefault("y2", "0"))
  
  of "polyline":
    result = SvgElement(kind: svgPolyline)
    result.points = parsePoints(node.attr("points"))
  
  of "polygon":
    result = SvgElement(kind: svgPolygon)
    result.points = parsePoints(node.attr("points"))
  
  of "g":
    result = SvgElement(kind: svgGroup)
    # Group can have its own attributes that children inherit
    var groupInherit = inherit
    if node.attrs.hasKey("fill"):
      groupInherit.fill = node.attr("fill")
      groupInherit.fillSet = true
    if node.attrs.hasKey("stroke"):
      groupInherit.stroke = node.attr("stroke")
    if node.attrs.hasKey("stroke-width"):
      groupInherit.strokeWidth = parseFloat32(node.attr("stroke-width"))
      groupInherit.strokeWidthSet = true
    
    for child in node:
      let childElem = parseSvgElement(child, groupInherit)
      if childElem.kind != svgUnknown:
        result.children.add(childElem)
  
  else:
    result = SvgElement(kind: svgUnknown)
    return
  
  # Parse common attributes with inheritance support
  result.fillSet = node.attrs.hasKey("fill") or inherit.fillSet
  result.fill = if node.attrs.hasKey("fill"): node.attr("fill") else: inherit.fill
  result.stroke = if node.attrs.hasKey("stroke"): node.attr("stroke") else: inherit.stroke
  
  # stroke-width: use inherited value if not set locally
  if node.attrs.hasKey("stroke-width"):
    result.strokeWidth = parseFloat32(node.attr("stroke-width"))
  elif inherit.strokeWidthSet:
    result.strokeWidth = inherit.strokeWidth
  else:
    result.strokeWidth = parseFloat32(node.attrOrDefault("stroke-width", "1"))
  
  result.transform = node.attr("transform")
  result.opacity = parseFloat32(node.attrOrDefault("opacity", "1"))
  result.hasClipPath = node.attr("clip-path").len > 0

proc parseSvg*(data: string): SvgDocument =
  ## Parse SVG XML data
  let root = parseXml(data)
  
  if root.tag != "svg":
    failInvalid("Root element must be <svg>")
  
  result = SvgDocument()
  
  # Parse dimensions
  let widthStr = root.attr("width")
  let heightStr = root.attr("height")
  let viewBoxStr = root.attr("viewBox")
  
  if widthStr.len > 0:
    result.width = int(parseFloat32(widthStr))
  if heightStr.len > 0:
    result.height = int(parseFloat32(heightStr))
  
  # Parse viewBox
  if viewBoxStr.len > 0:
    let parts = viewBoxStr.splitWhitespace()
    if parts.len == 4:
      result.viewBox = (
        x: parseFloat32(parts[0]),
        y: parseFloat32(parts[1]),
        width: parseFloat32(parts[2]),
        height: parseFloat32(parts[3])
      )
  
  # If no width/height, use viewBox
  if result.width == 0:
    result.width = int(result.viewBox.width)
  if result.height == 0:
    result.height = int(result.viewBox.height)
  
  # Extract root element attributes for inheritance
  var rootInherit = InheritedAttrs()
  if root.attrs.hasKey("fill"):
    rootInherit.fill = root.attr("fill")
    rootInherit.fillSet = true
  if root.attrs.hasKey("stroke"):
    rootInherit.stroke = root.attr("stroke")
  if root.attrs.hasKey("stroke-width"):
    rootInherit.strokeWidth = parseFloat32(root.attr("stroke-width"))
    rootInherit.strokeWidthSet = true
  
  # Parse child elements
  for child in root:
    case child.tag:
    of "defs":
      # Parse gradient definitions and other definitions (clip paths, etc.)
      # Elements inside defs are not rendered directly
      for defChild in child:
        case defChild.tag:
        of "linearGradient":
          let grad = parseLinearGradient(defChild)
          if grad.id.len > 0:
            result.gradients[grad.id] = grad
        of "radialGradient":
          let grad = parseRadialGradient(defChild)
          if grad.id.len > 0:
            result.gradients[grad.id] = grad
        of "clipPath":
          # Clip paths are referenced by other elements, not rendered directly
          # We could store them for future use, but for now we just skip them
          discard
        else:
          # Other elements inside defs (like paths with IDs) are not rendered
          # They are referenced by other elements via url(#id)
          discard
    of "linearGradient":
      let grad = parseLinearGradient(child)
      if grad.id.len > 0:
        result.gradients[grad.id] = grad
    of "radialGradient":
      let grad = parseRadialGradient(child)
      if grad.id.len > 0:
        result.gradients[grad.id] = grad
    else:
      let elem = parseSvgElement(child, rootInherit)
      if elem.kind != svgUnknown:
        result.elements.add(elem)

proc parseSvgFile*(filename: string): SvgDocument =
  ## Parse SVG from file
  let data = readFile(filename)
  result = parseSvg(data)

# Path parsing for SVG path data

type
  PathCommand = enum
    pcMove, pcLine, pcHLine, pcVLine, pcCubic, pcSCubic,
    pcQuad, pcTQuad, pcArc, pcClose,
    pcRMove, pcRLine, pcRHLine, pcRVLine, pcRCubic, pcRSCubic,
    pcRQuad, pcRTQuad, pcRArc

proc isRelative(cmd: PathCommand): bool =
  cmd in {pcRMove, pcRLine, pcRTQuad, pcRHLine, pcRVLine, 
          pcRCubic, pcRSCubic, pcRQuad, pcRArc}

proc paramCount(cmd: PathCommand): int =
  case cmd:
  of pcClose: 0
  of pcMove, pcLine, pcRMove, pcRLine, pcTQuad, pcRTQuad: 2
  of pcHLine, pcVLine, pcRHLine, pcRVLine: 1
  of pcCubic, pcRCubic: 6
  of pcSCubic, pcRSCubic, pcQuad, pcRQuad: 4
  of pcArc, pcRArc: 7

proc preprocessArcFlags(pathData: string): string =
  ## Preprocess path data to handle arc flags that are concatenated with subsequent numbers
  ## Arc format: rx ry rotation large-arc sweep x y
  ## large-arc and sweep are single 0/1 digits that may not have separators
  ## 
  ## This function handles cases like "017.82" which should be "0 1 7.82"
  ## (rotation=0, large-arc=0, sweep=1, x=7.82)
  result = ""
  var i = 0
  var inArc = false
  var arcParamCount = 0
  var lastCharInResult = ' '
  
  while i < pathData.len:
    let c = pathData[i]
    
    # Check for arc command
    if c == 'a' or c == 'A':
      inArc = true
      arcParamCount = 0
      result.add(c)
      lastCharInResult = c
      inc i
      continue
    
    # Check for other commands that would end the arc
    if c in "MmLlHhVvCcSsQqTtZz":
      inArc = false
      result.add(c)
      lastCharInResult = c
      inc i
      continue
    
    if inArc and c in "0123456789.-+":
      # Count arc parameters (rx, ry, rotation, large-arc, sweep, x, y)
      # Check if this is the start of a new number
      let isStartOfNumber = c in "-+" or lastCharInResult in " ,\t\n\rAa"
      
      if isStartOfNumber:
        inc arcParamCount
        # Arc parameters repeat every 7 values for multiple arc segments
        # large-arc flag (param 4) and sweep flag (param 5) are 0 or 1
        # and may be concatenated with the next number
        let arcParamMod = arcParamCount mod 7
        if arcParamMod == 4 or arcParamMod == 5:
          if c == '0' or c == '1':
            # Check if next char is a digit (part of next number)
            if i + 1 < pathData.len and pathData[i + 1] in "0123456789.":
              result.add(c)
              result.add(' ')
              lastCharInResult = ' '
              inc i
              continue
    
    result.add(c)
    lastCharInResult = c
    inc i

proc parsePathData*(pathData: string): seq[TinyVGPathNode] {.raises: [SvgError].} =
  ## Parse SVG path data string into TinyVG path nodes
  if pathData.len == 0:
    return

  # Preprocess to handle arc flag concatenation
  let processedPath = preprocessArcFlags(pathData)

  var
    p = 0
    numberStart = 0
    hitDecimal = false
    cmd: PathCommand
    numbers: seq[float32]
    currentX, currentY: float32
    subpathStartX, subpathStartY: float32  # Track subpath start for close command
    lastCpx2, lastCpy2: float32  # Last cubic bezier control point 2 (for smooth curves)
    nodes: seq[TinyVGPathNode]
    hasMoved = false  # Track if we've had at least one move command

  template finishNumber() =
    if numberStart > 0 and p > numberStart:
      try:
        numbers.add(parseFloat(processedPath[numberStart ..< p]).float32)
      except ValueError:
        failInvalid("Invalid path number: '" & processedPath[numberStart ..< p] & "'")
    numberStart = 0
    hitDecimal = false
  
  template finishCommand() =
    finishNumber()
    
    if numbers.len == 0:
      discard
    else:
      let count = paramCount(cmd)
      if count == 0:
        if cmd == pcClose:
          nodes.add(newPathClose())
      elif numbers.len mod count != 0:
        failInvalid("Wrong number of path parameters for command " & $cmd & ": expected multiple of " & $count & ", got " & $numbers.len)
      else:
        var i = 0
        while i < numbers.len:
          # Convert relative to absolute if needed
          let rel = isRelative(cmd)
          
          case cmd:
          of pcMove, pcRMove:
            let x = numbers[i]
            let y = numbers[i + 1]
            if rel:
              currentX += x
              currentY += y
            else:
              currentX = x
              currentY = y
            # Record subpath start for close command
            subpathStartX = currentX
            subpathStartY = currentY
            # If this is not the first move command, add a close to end the previous subpath
            if hasMoved:
              nodes.add(newPathClose())
            hasMoved = true
            # Add line to the new position (this acts as the move)
            nodes.add(newPathLine(currentX, currentY))
            i += 2
          
          of pcLine, pcRLine:
            let x = numbers[i]
            let y = numbers[i + 1]
            if rel:
              currentX += x
              currentY += y
            else:
              currentX = x
              currentY = y
            nodes.add(newPathLine(currentX, currentY))
            i += 2
          
          of pcHLine, pcRHLine:
            let x = numbers[i]
            if rel:
              currentX += x
            else:
              currentX = x
            nodes.add(newPathLine(currentX, currentY))
            i += 1
          
          of pcVLine, pcRVLine:
            let y = numbers[i]
            if rel:
              currentY += y
            else:
              currentY = y
            nodes.add(newPathLine(currentX, currentY))
            i += 1
          
          of pcCubic, pcRCubic:
            let x1 = numbers[i]
            let y1 = numbers[i + 1]
            let x2 = numbers[i + 2]
            let y2 = numbers[i + 3]
            let x = numbers[i + 4]
            let y = numbers[i + 5]
            
            var ax1, ay1, ax2, ay2, ax, ay: float32
            if rel:
              ax1 = currentX + x1
              ay1 = currentY + y1
              ax2 = currentX + x2
              ay2 = currentY + y2
              ax = currentX + x
              ay = currentY + y
            else:
              ax1 = x1
              ay1 = y1
              ax2 = x2
              ay2 = y2
              ax = x
              ay = y
            
            nodes.add(newPathBezier(ax1, ay1, ax2, ay2, ax, ay))
            currentX = ax
            currentY = ay
            # Save control point 2 for smooth bezier
            lastCpx2 = ax2
            lastCpy2 = ay2
            i += 6
          
          of pcSCubic, pcRSCubic:
            # Smooth cubic bezier - first control point is reflection of previous c2
            let x2 = numbers[i]
            let y2 = numbers[i + 1]
            let x = numbers[i + 2]
            let y = numbers[i + 3]
            
            var ax1, ay1, ax2, ay2, ax, ay: float32
            
            # First control point is reflection of last c2 around current point
            # If no previous cubic bezier, use current position
            if lastCpx2 == 0 and lastCpy2 == 0:
              ax1 = currentX
              ay1 = currentY
            else:
              ax1 = currentX * 2 - lastCpx2
              ay1 = currentY * 2 - lastCpy2
            
            if rel:
              ax2 = currentX + x2
              ay2 = currentY + y2
              ax = currentX + x
              ay = currentY + y
            else:
              ax2 = x2
              ay2 = y2
              ax = x
              ay = y
            
            nodes.add(newPathBezier(ax1, ay1, ax2, ay2, ax, ay))
            currentX = ax
            currentY = ay
            # Save control point 2 for next smooth bezier
            lastCpx2 = ax2
            lastCpy2 = ay2
            i += 4
          
          of pcQuad, pcRQuad:
            let x1 = numbers[i]
            let y1 = numbers[i + 1]
            let x = numbers[i + 2]
            let y = numbers[i + 3]
            
            var ax1, ay1, ax, ay: float32
            if rel:
              ax1 = currentX + x1
              ay1 = currentY + y1
              ax = currentX + x
              ay = currentY + y
            else:
              ax1 = x1
              ay1 = y1
              ax = x
              ay = y
            
            nodes.add(newPathQuadraticBezier(ax1, ay1, ax, ay))
            currentX = ax
            currentY = ay
            i += 4
          
          of pcArc, pcRArc:
            # SVG Arc: rx ry x-axis-rotation large-arc-flag sweep-flag x y
            let rx = numbers[i]
            let ry = numbers[i + 1]
            let rotation = numbers[i + 2]
            let largeArc = numbers[i + 3] != 0
            let sweep = numbers[i + 4] != 0
            let x = numbers[i + 5]
            let y = numbers[i + 6]
            
            var ax, ay: float32
            if rel:
              ax = currentX + x
              ay = currentY + y
            else:
              ax = x
              ay = y
            
            # Convert to TinyVG arc_ellipse (rx, ry, rotation, largeArc, sweep, endPoint)
            nodes.add(newPathArcEllipse(rx, ry, rotation, largeArc, sweep, ax, ay))
            currentX = ax
            currentY = ay
            i += 7
          
          of pcClose:
            nodes.add(newPathClose())
            # Reset current position to subpath start
            currentX = subpathStartX
            currentY = subpathStartY
            i += 0
          
          else:
            # Skip unsupported commands
            i += count
      numbers.setLen(0)
  
  while p < processedPath.len:
    let c = processedPath[p]

    case c:
    # Relative commands
    of 'm': finishCommand(); cmd = pcRMove
    of 'l': finishCommand(); cmd = pcRLine
    of 'h': finishCommand(); cmd = pcRHLine
    of 'v': finishCommand(); cmd = pcRVLine
    of 'c': finishCommand(); cmd = pcRCubic
    of 's': finishCommand(); cmd = pcRSCubic
    of 'q': finishCommand(); cmd = pcRQuad
    of 't': finishCommand(); cmd = pcRTQuad
    of 'a': finishCommand(); cmd = pcRArc
    of 'z', 'Z':
      finishCommand()
      nodes.add(newPathClose())
      # Reset current position to subpath start
      currentX = subpathStartX
      currentY = subpathStartY
    # Absolute commands
    of 'M': finishCommand(); cmd = pcMove
    of 'L': finishCommand(); cmd = pcLine
    of 'H': finishCommand(); cmd = pcHLine
    of 'V': finishCommand(); cmd = pcVLine
    of 'C': finishCommand(); cmd = pcCubic
    of 'S': finishCommand(); cmd = pcSCubic
    of 'Q': finishCommand(); cmd = pcQuad
    of 'T': finishCommand(); cmd = pcTQuad
    of 'A': finishCommand(); cmd = pcArc
    # Numbers
    of '-', '+':
      if numberStart == 0 or processedPath[p-1] in ['e', 'E']:
        if numberStart == 0:
          numberStart = p
      else:
        finishNumber()
        numberStart = p
    of '.':
      if hitDecimal:
        finishNumber()
        numberStart = p
        hitDecimal = true
      else:
        if numberStart == 0:
          numberStart = p
        hitDecimal = true
    of '0'..'9':
      if numberStart == 0:
        numberStart = p
    of ' ', '\t', '\n', '\r', ',':
      finishNumber()
    else:
      discard

    inc p
  
  finishCommand()
  result = nodes
