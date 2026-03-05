# SVG to TinyVG Converter
#
# Converts parsed SVG documents to TinyVG format

import std/[math, strutils, tables]
import svg, core

type
  SvgConverter* = object
    ## Converter state for SVG to TinyVG conversion
    colorMap: Table[string, int]
    gradientMap: Table[string, int]  ## Maps gradient ID to style index
    nextColorIndex: int
    svgDoc: ptr SvgDocument  ## Reference to source SVG document for gradient lookup

proc initConverter(): SvgConverter =
  ## Initialize a new SVG converter
  result = SvgConverter(nextColorIndex: 0, svgDoc: nil)

proc getOrAddColor(conv: var SvgConverter, doc: var TinyVGDocument, 
                   colorStr: string, isFill: bool = false): VGInt =
  ## Get or add a color to the palette
  ## Handles both color strings and gradient references (returns first stop color)
  ## For fills, empty string defaults to black (per SVG spec)
  if colorStr == "none":
    return -1
  
  if colorStr.len == 0:
    # Empty color string means no color (not set)
    return -1
  
  # Check if it's a gradient reference
  if colorStr.startsWith("url(#") and colorStr.endsWith(")"):
    if conv.svgDoc != nil:
      let gradId = colorStr[5..^2]  # Extract ID from "url(#id)"
      if gradId in conv.svgDoc.gradients:
        let svgGrad = conv.svgDoc.gradients[gradId]
        if svgGrad.stops.len > 0:
          # Return first stop color as fallback
          let stop = svgGrad.stops[0]
          let colorKey = "grad:" & gradId & ":0"
          if colorKey in conv.colorMap:
            return VGInt(conv.colorMap[colorKey])
          result = doc.addColor(stop.color.r, stop.color.g, stop.color.b, stop.color.a)
          conv.colorMap[colorKey] = int(result)
          return result
    return -1
  
  if colorStr in conv.colorMap:
    return VGInt(conv.colorMap[colorStr])
  
  let color = parseColor(colorStr)
  result = doc.addColor(color.r, color.g, color.b, color.a)
  conv.colorMap[colorStr] = int(result)

proc getFillColor(conv: var SvgConverter, doc: var TinyVGDocument, 
                  elem: SvgElement): VGInt =
  ## Get fill color for an element
  ## If fill attribute not set, default to black per SVG spec
  ## If fill attribute is set but empty, treat as transparent (no fill)
  if not elem.fillSet:
    return conv.getOrAddColor(doc, "black", true)
  elif elem.fill.len == 0:
    # Empty fill attribute means no fill
    return -1
  else:
    return conv.getOrAddColor(doc, elem.fill, true)

proc convertRect(conv: var SvgConverter, doc: var TinyVGDocument, 
                 elem: SvgElement) =
  ## Convert SVG rect to TinyVG
  let fillColor = conv.getFillColor(doc, elem)
  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)

  if fillColor >= 0 and strokeColor >= 0 and elem.strokeWidth > 0:
    # Outline fill rectangle
    doc.addOutlineFillRectangle(
      elem.x, elem.y, elem.width, elem.height,
      fillColor, strokeColor, elem.strokeWidth
    )
  elif fillColor >= 0:
    # Fill only
    doc.addFillRectangle(elem.x, elem.y, elem.width, elem.height, fillColor)
  elif strokeColor >= 0 and elem.strokeWidth > 0:
    # Stroke only - draw as 4 lines
    let x = elem.x
    let y = elem.y
    let w = elem.width
    let h = elem.height
    doc.addDrawLineLoop([
      (VGFloat(x), VGFloat(y)),
      (VGFloat(x + w), VGFloat(y)),
      (VGFloat(x + w), VGFloat(y + h)),
      (VGFloat(x), VGFloat(y + h))
    ], strokeColor, VGFloat(elem.strokeWidth))

proc convertCircle(conv: var SvgConverter, doc: var TinyVGDocument,
                   elem: SvgElement) =
  ## Convert SVG circle to TinyVG (approximated as polygon)
  let fillColor = conv.getFillColor(doc, elem)
  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)
  
  # Approximate circle with 32-sided polygon
  const segments = 32
  var points: seq[tuple[x, y: VGFloat]]
  
  for i in 0..<segments:
    let angle = 2.0 * PI * float32(i) / float32(segments)
    let px = elem.x + elem.r * cos(angle)
    let py = elem.y + elem.r * sin(angle)
    points.add((VGFloat(px), VGFloat(py)))
  
  if fillColor >= 0 and strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addOutlineFillPolygon(points, fillColor, strokeColor, VGFloat(elem.strokeWidth))
  elif fillColor >= 0:
    doc.addFillPolygon(points, fillColor)
  elif strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addDrawLineLoop(points, strokeColor, VGFloat(elem.strokeWidth))

proc convertEllipse(conv: var SvgConverter, doc: var TinyVGDocument,
                    elem: SvgElement) =
  ## Convert SVG ellipse to TinyVG (approximated as polygon)
  let fillColor = conv.getFillColor(doc, elem)
  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)
  
  # Approximate ellipse with 32-sided polygon
  const segments = 32
  var points: seq[tuple[x, y: VGFloat]]
  
  for i in 0..<segments:
    let angle = 2.0 * PI * float32(i) / float32(segments)
    let px = elem.x + elem.ellipseRx * cos(angle)
    let py = elem.y + elem.ellipseRy * sin(angle)
    points.add((VGFloat(px), VGFloat(py)))
  
  if fillColor >= 0 and strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addOutlineFillPolygon(points, fillColor, strokeColor, VGFloat(elem.strokeWidth))
  elif fillColor >= 0:
    doc.addFillPolygon(points, fillColor)
  elif strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addDrawLineLoop(points, strokeColor, VGFloat(elem.strokeWidth))

proc convertLine(conv: var SvgConverter, doc: var TinyVGDocument,
                 elem: SvgElement) =
  ## Convert SVG line to TinyVG
  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)
  if strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addDrawLines([
      (VGFloat(elem.x1), VGFloat(elem.y1)),
      (VGFloat(elem.x2), VGFloat(elem.y2))
    ], strokeColor, VGFloat(elem.strokeWidth))

proc convertPolyline(conv: var SvgConverter, doc: var TinyVGDocument,
                     elem: SvgElement) =
  ## Convert SVG polyline to TinyVG
  if elem.points.len < 2:
    return

  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)
  if strokeColor >= 0 and elem.strokeWidth > 0:
    var points: seq[tuple[x, y: VGFloat]]
    for p in elem.points:
      points.add((VGFloat(p.x), VGFloat(p.y)))
    doc.addDrawLineStrip(points, strokeColor, VGFloat(elem.strokeWidth))

proc convertPolygon(conv: var SvgConverter, doc: var TinyVGDocument,
                    elem: SvgElement) =
  ## Convert SVG polygon to TinyVG
  if elem.points.len < 3:
    return

  let fillColor = conv.getFillColor(doc, elem)
  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)
  
  var points: seq[tuple[x, y: VGFloat]]
  for p in elem.points:
    points.add((VGFloat(p.x), VGFloat(p.y)))
  
  if fillColor >= 0 and strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addOutlineFillPolygon(points, fillColor, strokeColor, VGFloat(elem.strokeWidth))
  elif fillColor >= 0:
    doc.addFillPolygon(points, fillColor)
  elif strokeColor >= 0 and elem.strokeWidth > 0:
    doc.addDrawLineLoop(points, strokeColor, VGFloat(elem.strokeWidth))

proc convertPath(conv: var SvgConverter, doc: var TinyVGDocument,
                 elem: SvgElement) =
  ## Convert SVG path to TinyVG
  if elem.d.len == 0:
    return
  
  let fillColor = conv.getFillColor(doc, elem)
  let strokeColor = conv.getOrAddColor(doc, elem.stroke, false)
  
  try:
    let pathNodes = parsePathData(elem.d)
    if pathNodes.len == 0:
      return
    
    # Find starting point
    var startX, startY: float32
    for node in pathNodes:
      if node.kind == line:
        # First line node is typically the move
        startX = node.lineX
        startY = node.lineY
        break
    
    if fillColor >= 0 and strokeColor >= 0 and elem.strokeWidth > 0:
      doc.addOutlineFillPath(
        (VGFloat(startX), VGFloat(startY)),
        pathNodes,
        fillColor,
        strokeColor,
        VGFloat(elem.strokeWidth)
      )
    elif fillColor >= 0:
      doc.addFillPath(
        (VGFloat(startX), VGFloat(startY)),
        pathNodes,
        fillColor
      )
    elif strokeColor >= 0 and elem.strokeWidth > 0:
      doc.addDrawLinePath(
        (VGFloat(startX), VGFloat(startY)),
        pathNodes,
        strokeColor,
        VGFloat(elem.strokeWidth)
      )
  except SvgError:
    # Skip invalid paths
    discard

proc convertGroup(conv: var SvgConverter, doc: var TinyVGDocument,
                  elem: SvgElement) =
  ## Convert SVG group to TinyVG (recursively convert children)
  for child in elem.children:
    case child.kind:
    of svgPath:
      convertPath(conv, doc, child)
    of svgRect:
      convertRect(conv, doc, child)
    of svgCircle:
      convertCircle(conv, doc, child)
    of svgEllipse:
      convertEllipse(conv, doc, child)
    of svgLine:
      convertLine(conv, doc, child)
    of svgPolyline:
      convertPolyline(conv, doc, child)
    of svgPolygon:
      convertPolygon(conv, doc, child)
    of svgGroup:
      convertGroup(conv, doc, child)
    of svgUnknown:
      discard

proc convertElement(conv: var SvgConverter, doc: var TinyVGDocument,
                    elem: SvgElement) =
  ## Convert a single SVG element
  case elem.kind:
  of svgPath:
    convertPath(conv, doc, elem)
  of svgRect:
    convertRect(conv, doc, elem)
  of svgCircle:
    convertCircle(conv, doc, elem)
  of svgEllipse:
    convertEllipse(conv, doc, elem)
  of svgLine:
    convertLine(conv, doc, elem)
  of svgPolyline:
    convertPolyline(conv, doc, elem)
  of svgPolygon:
    convertPolygon(conv, doc, elem)
  of svgGroup:
    convertGroup(conv, doc, elem)
  of svgUnknown:
    discard

proc preprocessSvg*(svgDoc: var SvgDocument) =
  ## Preprocess SVG document to prepare it for conversion
  ## - Merges paths without fill that are between two paths with the SAME fill color
  ##   (for hole creation using evenodd fill rule)
  ## - Clears pure clip path elements (paths that only serve as clip definitions)
  ## - Clears clip-path flags (clip paths not supported)
  
  # First, merge paths without fill that are "sandwiched" between two paths with the same fill color.
  # This indicates the no-fill path is a hole in the shape.
  # Example: fill=#fff, no-fill, fill=#fff → the no-fill path is a hole
  # Example: fill=#abc, no-fill, fill=#fff → the no-fill path is NOT a hole (separate outline)
  # Process from right to left to avoid size changes affecting subsequent comparisons
  var i = svgDoc.elements.len - 2
  while i > 0:
    let prev = svgDoc.elements[i - 1]
    let curr = svgDoc.elements[i]
    let next = svgDoc.elements[i + 1]
    
    # Check if we have: fill-A, no-fill, fill-A pattern (hole detection)
    # Only merge when:
    # 1. prev and next have the same fill color
    # 2. curr is significantly smaller than prev (likely a hole, not a separate shape)
    if prev.kind == svgPath and prev.d.len > 0 and prev.fillSet and
       curr.kind == svgPath and curr.d.len > 0 and not curr.fillSet and
       next.kind == svgPath and next.d.len > 0 and next.fillSet and
       prev.fill == next.fill and
       curr.d.len < prev.d.len div 4:  # Hole should be much smaller than container
      # The current no-fill path is a hole in the shape
      # Merge the hole path into the previous fill path (to maintain drawing order)
      svgDoc.elements[i - 1].d = prev.d & " " & curr.d
      
      # Clear the hole path
      svgDoc.elements[i].d = ""
      # Skip the previous path since we've handled this pattern
      i -= 2
    else:
      i -= 1
  
  # Clear clip-path flags - we don't support clip-path rendering
  # but we keep the paths as they might be valid shapes
  for i in 0 ..< svgDoc.elements.len:
    svgDoc.elements[i].hasClipPath = false

proc svgToTinyVG*(svgDoc: var SvgDocument): TinyVGDocument =
  ## Convert an SVG document to TinyVG format
  preprocessSvg(svgDoc)
  
  result = initTinyVGDocument(
    width = svgDoc.width,
    height = svgDoc.height,
    scale = 1.0,
    format = u8888
  )
  
  # Convert elements
  var conv = initConverter()
  # Store reference to SVG document for gradient lookup
  var svgDocPtr = unsafeAddr svgDoc
  conv.svgDoc = svgDocPtr
  for elem in svgDoc.elements:
    convertElement(conv, result, elem)

proc loadSvgAsTinyVG*(filename: string): TinyVGDocument =
  ## Load an SVG file and convert to TinyVG
  var svgDoc = parseSvgFile(filename)
  result = svgToTinyVG(svgDoc)

proc parseSvgAsTinyVG*(data: string): TinyVGDocument =
  ## Parse SVG data and convert to TinyVG
  var svgDoc = parseSvg(data)
  result = svgToTinyVG(svgDoc)
