# TinyVG Binary Format Reader and Writer
#
# The TinyVG binary format is a compact binary representation
# that uses variable-length encoding for integers and fixed-point
# representation for coordinates.

import std/[streams, endians, strutils]
import core

# Binary format constants
const
  TinyVGMagic* = 0x544756'u32  # "TGV" in little-endian (0x54='T', 0x47='G', 0x56='V')
  TinyVGCurrentVersion* = 1'u8
  MaxLeb128Bytes = 5  # Maximum bytes for uint32 LEB128 encoding

# Custom exception types
type
  TinyVGParsingError* = object of IOError
  TinyVGValidationError* = object of ValueError

# Command encoding in binary format
type
  BinaryCommandKind* = enum
    bFillRectangles = 0'u8
    bOutlineFillRectangles = 1'u8
    bDrawLines = 2'u8
    bDrawLineLoop = 3'u8
    bDrawLineStrip = 4'u8
    bFillPolygon = 5'u8
    bOutlineFillPolygon = 6'u8
    bDrawLinePath = 7'u8
    bFillPath = 8'u8
    bOutlineFillPath = 9'u8
    bTextHint = 10'u8

# Style encoding
type
  BinaryStyleKind* = enum
    bStyleFlat = 0'u8
    bStyleLinear = 1'u8
    bStyleRadial = 2'u8

# Path node encoding
type
  BinaryPathNodeKind* = enum
    bPathLine = 0'u8
    bPathHoriz = 1'u8
    bPathVert = 2'u8
    bPathBezier = 3'u8
    bPathQuadraticBezier = 4'u8
    bPathArcEllipse = 5'u8
    bPathArcCircle = 6'u8
    bPathClose = 7'u8

# Helper procedures for variable-length integer encoding
# Uses simple LEB128 (Little Endian Base 128) encoding
proc writeVarUInt(stream: Stream; value: uint32) =
  ## Write a variable-length unsigned integer (LEB128)
  var v = value
  while true:
    let byteVal = uint8(v and 0x7F)
    v = v shr 7
    if v != 0:
      stream.write(byteVal or 0x80)
    else:
      stream.write(byteVal)
      break

proc readVarUInt(stream: Stream): uint32 =
  ## Read a variable-length unsigned integer (LEB128)
  var shift = 0
  var byteCount = 0
  while true:
    if byteCount >= MaxLeb128Bytes:
      raise newException(TinyVGParsingError, "LEB128 encoding exceeds maximum bytes for uint32")
    let byteVal = uint32(stream.readUInt8())
    result = result or ((byteVal and 0x7F) shl shift)
    if (byteVal and 0x80) == 0:
      break
    shift += 7
    byteCount += 1
    if shift >= 32:
      raise newException(TinyVGParsingError, "LEB128 shift overflow")

# Helper for fixed-point coordinate encoding
proc writeFixed16(stream: Stream; value: float) =
  ## Write a 16.16 fixed-point number
  ## Range: [-32768.0, 32767.999985]
  const MaxFixed16 = 32767.999985
  const MinFixed16 = -32768.0
  if value > MaxFixed16:
    raise newException(TinyVGValidationError, "Fixed16 value exceeds maximum: " & $value)
  if value < MinFixed16:
    raise newException(TinyVGValidationError, "Fixed16 value below minimum: " & $value)
  let fixed = int32(value * 65536.0)
  var leFixed = fixed.int32
  littleEndian32(addr leFixed, addr fixed)
  stream.write(leFixed)

proc readFixed16(stream: Stream): float =
  ## Read a 16.16 fixed-point number
  var leFixed = stream.readInt32()
  var fixed: int32
  littleEndian32(addr fixed, addr leFixed)
  result = float(fixed) / 65536.0

proc writeFixed8(stream: Stream; value: float) =
  ## Write an 8.8 fixed-point number
  ## Range: [-128.0, 127.996]
  const MaxFixed8 = 127.996
  const MinFixed8 = -128.0
  if value > MaxFixed8:
    raise newException(TinyVGValidationError, "Fixed8 value exceeds maximum: " & $value)
  if value < MinFixed8:
    raise newException(TinyVGValidationError, "Fixed8 value below minimum: " & $value)
  let fixed = int16(value * 256.0)
  var leFixed = fixed.int16
  littleEndian16(addr leFixed, addr fixed)
  stream.write(leFixed)

proc readFixed8(stream: Stream): float =
  ## Read an 8.8 fixed-point number
  var leFixed = stream.readInt16()
  var fixed: int16
  littleEndian16(addr fixed, addr leFixed)
  result = float(fixed) / 256.0

# Helper to write style to binary
proc writeStyle(stream: Stream; style: TinyVGStyle) =
  ## Write a style to binary format
  case style.kind:
    of flat:
      stream.write(uint8(bStyleFlat))
      writeVarUInt(stream, uint32(style.flatColorIndex))
    of linear:
      stream.write(uint8(bStyleLinear))
      writeFixed16(stream, style.linearStartPoint.x)
      writeFixed16(stream, style.linearStartPoint.y)
      writeFixed16(stream, style.linearEndPoint.x)
      writeFixed16(stream, style.linearEndPoint.y)
      writeVarUInt(stream, uint32(style.linearStartColorIndex))
      writeVarUInt(stream, uint32(style.linearEndColorIndex))
    of radial:
      stream.write(uint8(bStyleRadial))
      writeFixed16(stream, style.radialStartPoint.x)
      writeFixed16(stream, style.radialStartPoint.y)
      writeFixed16(stream, style.radialEndPoint.x)
      writeFixed16(stream, style.radialEndPoint.y)
      writeVarUInt(stream, uint32(style.radialStartColorIndex))
      writeVarUInt(stream, uint32(style.radialEndColorIndex))

# Helper to read style from binary
proc readStyle(stream: Stream): TinyVGStyle =
  ## Read a style from binary format
  let styleKind = stream.readUInt8()
  case styleKind:
    of 0:  # bStyleFlat
      let colorIndex = VGInt(readVarUInt(stream))
      result = TinyVGStyle(kind: flat, flatColorIndex: colorIndex)
    of 1:  # bStyleLinear
      let x1 = readFixed16(stream)
      let y1 = readFixed16(stream)
      let x2 = readFixed16(stream)
      let y2 = readFixed16(stream)
      let startIdx = VGInt(readVarUInt(stream))
      let endIdx = VGInt(readVarUInt(stream))
      result = TinyVGStyle(
        kind: linear,
        linearStartPoint: (x1, y1),
        linearEndPoint: (x2, y2),
        linearStartColorIndex: startIdx,
        linearEndColorIndex: endIdx
      )
    of 2:  # bStyleRadial
      let x1 = readFixed16(stream)
      let y1 = readFixed16(stream)
      let x2 = readFixed16(stream)
      let y2 = readFixed16(stream)
      let startIdx = VGInt(readVarUInt(stream))
      let endIdx = VGInt(readVarUInt(stream))
      result = TinyVGStyle(
        kind: radial,
        radialStartPoint: (x1, y1),
        radialEndPoint: (x2, y2),
        radialStartColorIndex: startIdx,
        radialEndColorIndex: endIdx
      )
    else:
      raise newException(TinyVGParsingError, "Unknown style kind: " & $styleKind)

# Helper to validate color index
proc validateColorIndex(index: int; paletteLen: int; context: string) =
  ## Validate that a color index is within bounds
  if index < 0 or index >= paletteLen:
    raise newException(TinyVGValidationError, 
      context & ": color index " & $index & " out of bounds (palette size: " & $paletteLen & ")")

# Write TinyVG document to binary format
proc writeTinyVGBinary*(doc: TinyVGDocument; stream: Stream) =
  ## Write a TinyVG document to binary format
  
  # Magic number (little-endian)
  var magicLe: uint32 = TinyVGMagic
  var magicBe = TinyVGMagic
  littleEndian32(addr magicLe, addr magicBe)
  stream.write(magicLe)
  
  # Version
  stream.write(uint8(doc.header.version))
  
  # Scale (as 8.8 fixed-point)
  writeFixed8(stream, float(doc.header.scale))
  
  # Format and precision (packed into one byte)
  let formatByte = (uint8(doc.header.format) shl 4) or uint8(doc.header.precision)
  stream.write(formatByte)
  
  # Canvas size (variable-length encoded)
  if doc.header.width < 0:
    raise newException(TinyVGValidationError, "Width cannot be negative: " & $doc.header.width)
  if doc.header.height < 0:
    raise newException(TinyVGValidationError, "Height cannot be negative: " & $doc.header.height)
  writeVarUInt(stream, uint32(doc.header.width))
  writeVarUInt(stream, uint32(doc.header.height))
  
  # Color count and palette
  writeVarUInt(stream, uint32(doc.palette.len))
  for i, color in doc.palette:
    case doc.header.format:
      of u8888:
        # Write RGBA8888
        let r = uint8(color.r * 255.0)
        let g = uint8(color.g * 255.0)
        let b = uint8(color.b * 255.0)
        let a = uint8(color.a * 255.0)
        stream.write(r)
        stream.write(g)
        stream.write(b)
        stream.write(a)
      of u888:
        # Write RGB888
        let r = uint8(color.r * 255.0)
        let g = uint8(color.g * 255.0)
        let b = uint8(color.b * 255.0)
        stream.write(r)
        stream.write(g)
        stream.write(b)
  
  # Command count
  writeVarUInt(stream, uint32(doc.commands.len))
  
  # Commands
  for cmd in doc.commands:
    # Command kind
    let cmdKind = case cmd.kind:
      of fill_rectangles: bFillRectangles
      of outline_fill_rectangles: bOutlineFillRectangles
      of draw_lines: bDrawLines
      of draw_line_loop: bDrawLineLoop
      of draw_line_strip: bDrawLineStrip
      of fill_polygon: bFillPolygon
      of outline_fill_polygon: bOutlineFillPolygon
      of draw_line_path: bDrawLinePath
      of fill_path: bFillPath
      of outline_fill_path: bOutlineFillPath
      of text_hint: bTextHint
    stream.write(uint8(cmdKind))
    
    # Command-specific data
    case cmd.kind:
      of fill_rectangles:
        # Style
        writeStyle(stream, cmd.fillStyle)
        # Rectangles
        writeVarUInt(stream, uint32(cmd.rectangles.len))
        for rect in cmd.rectangles:
          writeFixed16(stream, float(rect.x))
          writeFixed16(stream, float(rect.y))
          writeFixed16(stream, float(rect.width))
          writeFixed16(stream, float(rect.height))
      
      of outline_fill_rectangles:
        # Fill style
        writeStyle(stream, cmd.fillStyle)
        # Line style
        writeStyle(stream, cmd.lineStyle)
        # Line width
        writeFixed8(stream, float(cmd.lineWidth))
        # Rectangles
        writeVarUInt(stream, uint32(cmd.rectangles.len))
        for rect in cmd.rectangles:
          writeFixed16(stream, float(rect.x))
          writeFixed16(stream, float(rect.y))
          writeFixed16(stream, float(rect.width))
          writeFixed16(stream, float(rect.height))
      
      of draw_lines, draw_line_loop, draw_line_strip:
        # Line style
        writeStyle(stream, cmd.lineStyle)
        # Line width
        writeFixed8(stream, float(cmd.lineWidth))
        # Points
        writeVarUInt(stream, uint32(cmd.points.len))
        for point in cmd.points:
          writeFixed16(stream, float(point.x))
          writeFixed16(stream, float(point.y))
      
      of fill_polygon, outline_fill_polygon:
        # Fill style
        writeStyle(stream, cmd.fillStyle)
        if cmd.kind == outline_fill_polygon:
          # Line style
          writeStyle(stream, cmd.lineStyle)
          # Line width
          writeFixed8(stream, float(cmd.lineWidth))
        # Points
        writeVarUInt(stream, uint32(cmd.points.len))
        for point in cmd.points:
          writeFixed16(stream, float(point.x))
          writeFixed16(stream, float(point.y))
      
      of draw_line_path:
        # Line style
        writeStyle(stream, cmd.lineStyle)
        # Line width
        writeFixed8(stream, float(cmd.lineWidth))
        # Start point
        writeFixed16(stream, float(cmd.startPoint.x))
        writeFixed16(stream, float(cmd.startPoint.y))
        # Path nodes
        writeVarUInt(stream, uint32(cmd.pathNodes.len))
        for node in cmd.pathNodes:
          writeFixed8(stream, float(node.lineWidthChange))
          case node.kind:
            of horiz:
              stream.write(uint8(bPathHoriz))
              writeFixed16(stream, float(node.horizX))
            of vert:
              stream.write(uint8(bPathVert))
              writeFixed16(stream, float(node.vertY))
            of line:
              stream.write(uint8(bPathLine))
              writeFixed16(stream, float(node.lineX))
              writeFixed16(stream, float(node.lineY))
            of bezier:
              stream.write(uint8(bPathBezier))
              writeFixed16(stream, float(node.bezierControl1.x))
              writeFixed16(stream, float(node.bezierControl1.y))
              writeFixed16(stream, float(node.bezierControl2.x))
              writeFixed16(stream, float(node.bezierControl2.y))
              writeFixed16(stream, float(node.bezierEndPoint.x))
              writeFixed16(stream, float(node.bezierEndPoint.y))
            of quadratic_bezier:
              stream.write(uint8(bPathQuadraticBezier))
              writeFixed16(stream, float(node.quadControl.x))
              writeFixed16(stream, float(node.quadControl.y))
              writeFixed16(stream, float(node.quadEndPoint.x))
              writeFixed16(stream, float(node.quadEndPoint.y))
            of arc_ellipse:
              stream.write(uint8(bPathArcEllipse))
              writeFixed16(stream, float(node.arcRadiusX))
              writeFixed16(stream, float(node.arcRadiusY))
              writeFixed16(stream, float(node.arcAngle))
              stream.write(uint8(if node.arcLargeArc: 1'u8 else: 0'u8))
              stream.write(uint8(if node.arcSweep: 1'u8 else: 0'u8))
              writeFixed16(stream, float(node.arcEndPoint.x))
              writeFixed16(stream, float(node.arcEndPoint.y))
            of arc_circle:
              stream.write(uint8(bPathArcCircle))
              writeFixed16(stream, float(node.circleRadius))
              stream.write(uint8(if node.circleLargeArc: 1'u8 else: 0'u8))
              stream.write(uint8(if node.circleSweep: 1'u8 else: 0'u8))
              writeFixed16(stream, float(node.circleEndPoint.x))
              writeFixed16(stream, float(node.circleEndPoint.y))
            of close:
              stream.write(uint8(bPathClose))
        # Stroke
        stream.write(uint8(0))  # End marker
      
      of fill_path:
        # Fill style
        writeStyle(stream, cmd.fillStyle)
        # Start point
        writeFixed16(stream, float(cmd.startPoint.x))
        writeFixed16(stream, float(cmd.startPoint.y))
        # Path nodes
        writeVarUInt(stream, uint32(cmd.pathNodes.len))
        for node in cmd.pathNodes:
          writeFixed8(stream, float(node.lineWidthChange))
          case node.kind:
            of horiz:
              stream.write(uint8(bPathHoriz))
              writeFixed16(stream, float(node.horizX))
            of vert:
              stream.write(uint8(bPathVert))
              writeFixed16(stream, float(node.vertY))
            of line:
              stream.write(uint8(bPathLine))
              writeFixed16(stream, float(node.lineX))
              writeFixed16(stream, float(node.lineY))
            of bezier:
              stream.write(uint8(bPathBezier))
              writeFixed16(stream, float(node.bezierControl1.x))
              writeFixed16(stream, float(node.bezierControl1.y))
              writeFixed16(stream, float(node.bezierControl2.x))
              writeFixed16(stream, float(node.bezierControl2.y))
              writeFixed16(stream, float(node.bezierEndPoint.x))
              writeFixed16(stream, float(node.bezierEndPoint.y))
            of quadratic_bezier:
              stream.write(uint8(bPathQuadraticBezier))
              writeFixed16(stream, float(node.quadControl.x))
              writeFixed16(stream, float(node.quadControl.y))
              writeFixed16(stream, float(node.quadEndPoint.x))
              writeFixed16(stream, float(node.quadEndPoint.y))
            of arc_ellipse:
              stream.write(uint8(bPathArcEllipse))
              writeFixed16(stream, float(node.arcRadiusX))
              writeFixed16(stream, float(node.arcRadiusY))
              writeFixed16(stream, float(node.arcAngle))
              stream.write(uint8(if node.arcLargeArc: 1'u8 else: 0'u8))
              stream.write(uint8(if node.arcSweep: 1'u8 else: 0'u8))
              writeFixed16(stream, float(node.arcEndPoint.x))
              writeFixed16(stream, float(node.arcEndPoint.y))
            of arc_circle:
              stream.write(uint8(bPathArcCircle))
              writeFixed16(stream, float(node.circleRadius))
              stream.write(uint8(if node.circleLargeArc: 1'u8 else: 0'u8))
              stream.write(uint8(if node.circleSweep: 1'u8 else: 0'u8))
              writeFixed16(stream, float(node.circleEndPoint.x))
              writeFixed16(stream, float(node.circleEndPoint.y))
            of close:
              stream.write(uint8(bPathClose))
        # Fill
        stream.write(uint8(1))  # Fill marker
      
      of outline_fill_path:
        # Fill style
        writeStyle(stream, cmd.fillStyle)
        # Line style
        writeStyle(stream, cmd.lineStyle)
        # Line width
        writeFixed8(stream, float(cmd.lineWidth))
        # Start point
        writeFixed16(stream, float(cmd.startPoint.x))
        writeFixed16(stream, float(cmd.startPoint.y))
        # Path nodes
        writeVarUInt(stream, uint32(cmd.pathNodes.len))
        for node in cmd.pathNodes:
          writeFixed8(stream, float(node.lineWidthChange))
          case node.kind:
            of horiz:
              stream.write(uint8(bPathHoriz))
              writeFixed16(stream, float(node.horizX))
            of vert:
              stream.write(uint8(bPathVert))
              writeFixed16(stream, float(node.vertY))
            of line:
              stream.write(uint8(bPathLine))
              writeFixed16(stream, float(node.lineX))
              writeFixed16(stream, float(node.lineY))
            of bezier:
              stream.write(uint8(bPathBezier))
              writeFixed16(stream, float(node.bezierControl1.x))
              writeFixed16(stream, float(node.bezierControl1.y))
              writeFixed16(stream, float(node.bezierControl2.x))
              writeFixed16(stream, float(node.bezierControl2.y))
              writeFixed16(stream, float(node.bezierEndPoint.x))
              writeFixed16(stream, float(node.bezierEndPoint.y))
            of quadratic_bezier:
              stream.write(uint8(bPathQuadraticBezier))
              writeFixed16(stream, float(node.quadControl.x))
              writeFixed16(stream, float(node.quadControl.y))
              writeFixed16(stream, float(node.quadEndPoint.x))
              writeFixed16(stream, float(node.quadEndPoint.y))
            of arc_ellipse:
              stream.write(uint8(bPathArcEllipse))
              writeFixed16(stream, float(node.arcRadiusX))
              writeFixed16(stream, float(node.arcRadiusY))
              writeFixed16(stream, float(node.arcAngle))
              stream.write(uint8(if node.arcLargeArc: 1'u8 else: 0'u8))
              stream.write(uint8(if node.arcSweep: 1'u8 else: 0'u8))
              writeFixed16(stream, float(node.arcEndPoint.x))
              writeFixed16(stream, float(node.arcEndPoint.y))
            of arc_circle:
              stream.write(uint8(bPathArcCircle))
              writeFixed16(stream, float(node.circleRadius))
              stream.write(uint8(if node.circleLargeArc: 1'u8 else: 0'u8))
              stream.write(uint8(if node.circleSweep: 1'u8 else: 0'u8))
              writeFixed16(stream, float(node.circleEndPoint.x))
              writeFixed16(stream, float(node.circleEndPoint.y))
            of close:
              stream.write(uint8(bPathClose))
        # Fill and stroke
        stream.write(uint8(2))  # Both fill and stroke marker
      
      of text_hint:
        # Center point
        writeFixed16(stream, float(cmd.centerX))
        writeFixed16(stream, float(cmd.centerY))
        # Rotation
        writeFixed16(stream, float(cmd.rotation))
        # Height
        writeFixed16(stream, float(cmd.height))
        # Content length and content
        writeVarUInt(stream, uint32(cmd.content.len))
        stream.write(cmd.content)
        # Glyphs
        writeVarUInt(stream, uint32(cmd.glyphs.len))
        for glyph in cmd.glyphs:
          writeVarUInt(stream, uint32(glyph.startOffset))
          writeVarUInt(stream, uint32(glyph.endOffset))

proc writeTinyVGBinary*(doc: TinyVGDocument; filename: string) =
  ## Write a TinyVG document to a binary file
  var stream = newFileStream(filename, fmWrite)
  if stream.isNil:
    raise newException(IOError, "Cannot open file for writing: " & filename)
  try:
    writeTinyVGBinary(doc, stream)
  finally:
    stream.close()

# Read TinyVG document from binary format
proc readTinyVGBinary*(stream: Stream): TinyVGDocument =
  ## Read a TinyVG document from binary format
  
  # Magic number (little-endian)
  var magicLe = stream.readUInt32()
  var magic: uint32
  littleEndian32(addr magic, addr magicLe)
  if magic != TinyVGMagic:
    raise newException(TinyVGParsingError, "Invalid TinyVG binary file (wrong magic number: " & $magic.toHex & ")")
  
  # Version
  result.header.version = stream.readUInt8()
  
  # Scale
  result.header.scale = VGFloat(readFixed8(stream))
  
  # Format and precision
  let formatByte = stream.readUInt8()
  result.header.format = TinyVGFormat((formatByte shr 4) and 0x0F)
  result.header.precision = TinyVGPrecision(formatByte and 0x0F)
  
  # Canvas size
  result.header.width = TinyVGWidth(readVarUInt(stream))
  result.header.height = TinyVGHeight(readVarUInt(stream))
  
  # Color count and palette
  let colorCount = int(readVarUInt(stream))
  result.palette = newSeq[TinyVGColor](colorCount)
  for i in 0..<colorCount:
    case result.header.format:
      of u8888:
        let r = VGFloat(stream.readUInt8()) / 255.0
        let g = VGFloat(stream.readUInt8()) / 255.0
        let b = VGFloat(stream.readUInt8()) / 255.0
        let a = VGFloat(stream.readUInt8()) / 255.0
        result.palette[i] = TinyVGColor(r: r, g: g, b: b, a: a)
      of u888:
        let r = VGFloat(stream.readUInt8()) / 255.0
        let g = VGFloat(stream.readUInt8()) / 255.0
        let b = VGFloat(stream.readUInt8()) / 255.0
        result.palette[i] = TinyVGColor(r: r, g: g, b: b, a: 1.0)
  
  # Command count
  let commandCount = int(readVarUInt(stream))
  result.commands = newSeq[TinyVGCommand](commandCount)
  
  # Commands
  for i in 0..<commandCount:
    let cmdKindByte = stream.readUInt8()
    let cmdKind = case cmdKindByte:
      of 0: fill_rectangles
      of 1: outline_fill_rectangles
      of 2: draw_lines
      of 3: draw_line_loop
      of 4: draw_line_strip
      of 5: fill_polygon
      of 6: outline_fill_polygon
      of 7: draw_line_path
      of 8: fill_path
      of 9: outline_fill_path
      of 10: text_hint
      else: raise newException(TinyVGParsingError, "Unknown command kind: " & $cmdKindByte)
    
    result.commands[i].kind = cmdKind
    
    # Command-specific data
    case cmdKind:
      of fill_rectangles:
        # Style
        result.commands[i].fillStyle = readStyle(stream)
        # Rectangles
        let rectCount = int(readVarUInt(stream))
        result.commands[i].rectangles = newSeq[VGRectangle](rectCount)
        for j in 0..<rectCount:
          result.commands[i].rectangles[j].x = VGFloat(readFixed16(stream))
          result.commands[i].rectangles[j].y = VGFloat(readFixed16(stream))
          result.commands[i].rectangles[j].width = VGFloat(readFixed16(stream))
          result.commands[i].rectangles[j].height = VGFloat(readFixed16(stream))
      
      of outline_fill_rectangles:
        # Fill style
        result.commands[i].fillStyle = readStyle(stream)
        # Line style
        result.commands[i].lineStyle = readStyle(stream)
        # Line width
        result.commands[i].lineWidth = VGFloat(readFixed8(stream))
        # Rectangles
        let rectCount = int(readVarUInt(stream))
        result.commands[i].rectangles = newSeq[VGRectangle](rectCount)
        for j in 0..<rectCount:
          result.commands[i].rectangles[j].x = VGFloat(readFixed16(stream))
          result.commands[i].rectangles[j].y = VGFloat(readFixed16(stream))
          result.commands[i].rectangles[j].width = VGFloat(readFixed16(stream))
          result.commands[i].rectangles[j].height = VGFloat(readFixed16(stream))
      
      of draw_lines, draw_line_loop, draw_line_strip:
        # Line style
        result.commands[i].lineStyle = readStyle(stream)
        # Line width
        result.commands[i].lineWidth = VGFloat(readFixed8(stream))
        # Points
        let pointCount = int(readVarUInt(stream))
        result.commands[i].points = newSeq[VGPoint](pointCount)
        for j in 0..<pointCount:
          result.commands[i].points[j].x = VGFloat(readFixed16(stream))
          result.commands[i].points[j].y = VGFloat(readFixed16(stream))
      
      of fill_polygon, outline_fill_polygon:
        # Fill style
        result.commands[i].fillStyle = readStyle(stream)
        if cmdKind == outline_fill_polygon:
          # Line style
          result.commands[i].lineStyle = readStyle(stream)
          # Line width
          result.commands[i].lineWidth = VGFloat(readFixed8(stream))
        # Points
        let pointCount = int(readVarUInt(stream))
        result.commands[i].points = newSeq[VGPoint](pointCount)
        for j in 0..<pointCount:
          result.commands[i].points[j].x = VGFloat(readFixed16(stream))
          result.commands[i].points[j].y = VGFloat(readFixed16(stream))
      
      of draw_line_path:
        # Line style
        result.commands[i].lineStyle = readStyle(stream)
        # Line width
        result.commands[i].lineWidth = VGFloat(readFixed8(stream))
        # Start point
        let startX = VGFloat(readFixed16(stream))
        let startY = VGFloat(readFixed16(stream))
        result.commands[i].startPoint = (startX, startY)
        # Path nodes
        let nodeCount = int(readVarUInt(stream))
        result.commands[i].pathNodes = newSeq[TinyVGPathNode](nodeCount)
        for j in 0..<nodeCount:
          let lineWidthChange = VGFloat(readFixed8(stream))
          let nodeKindByte = stream.readUInt8()
          case nodeKindByte:
            of 1:  # bPathHoriz
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: horiz,
                lineWidthChange: lineWidthChange,
                horizX: VGFloat(readFixed16(stream))
              )
            of 2:  # bPathVert
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: vert,
                lineWidthChange: lineWidthChange,
                vertY: VGFloat(readFixed16(stream))
              )
            of 0:  # bPathLine
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: line,
                lineWidthChange: lineWidthChange,
                lineX: VGFloat(readFixed16(stream)),
                lineY: VGFloat(readFixed16(stream))
              )
            of 3:  # bPathBezier
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: bezier,
                lineWidthChange: lineWidthChange,
                bezierControl1: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                bezierControl2: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                bezierEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 4:  # bPathQuadraticBezier
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: quadratic_bezier,
                lineWidthChange: lineWidthChange,
                quadControl: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                quadEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 5:  # bPathArcEllipse
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: arc_ellipse,
                lineWidthChange: lineWidthChange,
                arcRadiusX: VGFloat(readFixed16(stream)),
                arcRadiusY: VGFloat(readFixed16(stream)),
                arcAngle: VGFloat(readFixed16(stream)),
                arcLargeArc: stream.readUInt8() != 0,
                arcSweep: stream.readUInt8() != 0,
                arcEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 6:  # bPathArcCircle
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: arc_circle,
                lineWidthChange: lineWidthChange,
                circleRadius: VGFloat(readFixed16(stream)),
                circleLargeArc: stream.readUInt8() != 0,
                circleSweep: stream.readUInt8() != 0,
                circleEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 7:  # bPathClose
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: close,
                lineWidthChange: lineWidthChange
              )
            else:
              raise newException(TinyVGParsingError, "Unknown path node kind: " & $nodeKindByte)
        discard stream.readUInt8()  # End marker
      
      of fill_path:
        # Fill style
        result.commands[i].fillStyle = readStyle(stream)
        # Start point
        let startX = VGFloat(readFixed16(stream))
        let startY = VGFloat(readFixed16(stream))
        result.commands[i].startPoint = (startX, startY)
        # Path nodes
        let nodeCount = int(readVarUInt(stream))
        result.commands[i].pathNodes = newSeq[TinyVGPathNode](nodeCount)
        for j in 0..<nodeCount:
          let lineWidthChange = VGFloat(readFixed8(stream))
          let nodeKindByte = stream.readUInt8()
          case nodeKindByte:
            of 1:  # bPathHoriz
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: horiz,
                lineWidthChange: lineWidthChange,
                horizX: VGFloat(readFixed16(stream))
              )
            of 2:  # bPathVert
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: vert,
                lineWidthChange: lineWidthChange,
                vertY: VGFloat(readFixed16(stream))
              )
            of 0:  # bPathLine
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: line,
                lineWidthChange: lineWidthChange,
                lineX: VGFloat(readFixed16(stream)),
                lineY: VGFloat(readFixed16(stream))
              )
            of 3:  # bPathBezier
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: bezier,
                lineWidthChange: lineWidthChange,
                bezierControl1: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                bezierControl2: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                bezierEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 4:  # bPathQuadraticBezier
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: quadratic_bezier,
                lineWidthChange: lineWidthChange,
                quadControl: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                quadEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 5:  # bPathArcEllipse
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: arc_ellipse,
                lineWidthChange: lineWidthChange,
                arcRadiusX: VGFloat(readFixed16(stream)),
                arcRadiusY: VGFloat(readFixed16(stream)),
                arcAngle: VGFloat(readFixed16(stream)),
                arcLargeArc: stream.readUInt8() != 0,
                arcSweep: stream.readUInt8() != 0,
                arcEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 6:  # bPathArcCircle
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: arc_circle,
                lineWidthChange: lineWidthChange,
                circleRadius: VGFloat(readFixed16(stream)),
                circleLargeArc: stream.readUInt8() != 0,
                circleSweep: stream.readUInt8() != 0,
                circleEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 7:  # bPathClose
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: close,
                lineWidthChange: lineWidthChange
              )
            else:
              raise newException(TinyVGParsingError, "Unknown path node kind: " & $nodeKindByte)
        discard stream.readUInt8()  # Fill marker
      
      of outline_fill_path:
        # Fill style
        result.commands[i].fillStyle = readStyle(stream)
        # Line style
        result.commands[i].lineStyle = readStyle(stream)
        # Line width
        result.commands[i].lineWidth = VGFloat(readFixed8(stream))
        # Start point
        let startX = VGFloat(readFixed16(stream))
        let startY = VGFloat(readFixed16(stream))
        result.commands[i].startPoint = (startX, startY)
        # Path nodes
        let nodeCount = int(readVarUInt(stream))
        result.commands[i].pathNodes = newSeq[TinyVGPathNode](nodeCount)
        for j in 0..<nodeCount:
          let lineWidthChange = VGFloat(readFixed8(stream))
          let nodeKindByte = stream.readUInt8()
          case nodeKindByte:
            of 1:  # bPathHoriz
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: horiz,
                lineWidthChange: lineWidthChange,
                horizX: VGFloat(readFixed16(stream))
              )
            of 2:  # bPathVert
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: vert,
                lineWidthChange: lineWidthChange,
                vertY: VGFloat(readFixed16(stream))
              )
            of 0:  # bPathLine
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: line,
                lineWidthChange: lineWidthChange,
                lineX: VGFloat(readFixed16(stream)),
                lineY: VGFloat(readFixed16(stream))
              )
            of 3:  # bPathBezier
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: bezier,
                lineWidthChange: lineWidthChange,
                bezierControl1: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                bezierControl2: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                bezierEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 4:  # bPathQuadraticBezier
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: quadratic_bezier,
                lineWidthChange: lineWidthChange,
                quadControl: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream))),
                quadEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 5:  # bPathArcEllipse
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: arc_ellipse,
                lineWidthChange: lineWidthChange,
                arcRadiusX: VGFloat(readFixed16(stream)),
                arcRadiusY: VGFloat(readFixed16(stream)),
                arcAngle: VGFloat(readFixed16(stream)),
                arcLargeArc: stream.readUInt8() != 0,
                arcSweep: stream.readUInt8() != 0,
                arcEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 6:  # bPathArcCircle
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: arc_circle,
                lineWidthChange: lineWidthChange,
                circleRadius: VGFloat(readFixed16(stream)),
                circleLargeArc: stream.readUInt8() != 0,
                circleSweep: stream.readUInt8() != 0,
                circleEndPoint: (VGFloat(readFixed16(stream)), VGFloat(readFixed16(stream)))
              )
            of 7:  # bPathClose
              result.commands[i].pathNodes[j] = TinyVGPathNode(
                kind: close,
                lineWidthChange: lineWidthChange
              )
            else:
              raise newException(TinyVGParsingError, "Unknown path node kind: " & $nodeKindByte)
        discard stream.readUInt8()  # Both fill and stroke marker
      
      of text_hint:
        # Center point
        result.commands[i].centerX = VGFloat(readFixed16(stream))
        result.commands[i].centerY = VGFloat(readFixed16(stream))
        # Rotation
        result.commands[i].rotation = VGFloat(readFixed16(stream))
        # Height
        result.commands[i].height = VGFloat(readFixed16(stream))
        # Content
        let contentLen = int(readVarUInt(stream))
        var content = newString(contentLen)
        if contentLen > 0:
          let bytesRead = stream.readData(addr content[0], contentLen)
          if bytesRead != contentLen:
            raise newException(TinyVGParsingError, "Failed to read text content")
        result.commands[i].content = content
        # Glyphs
        let glyphCount = int(readVarUInt(stream))
        result.commands[i].glyphs = newSeq[VGGlyph](glyphCount)
        for j in 0..<glyphCount:
          let startOffset = VGInt(readVarUInt(stream))
          let endOffset = VGInt(readVarUInt(stream))
          result.commands[i].glyphs[j] = (startOffset, endOffset)

proc readTinyVGBinary*(filename: string): TinyVGDocument =
  ## Read a TinyVG document from a binary file
  var stream = newFileStream(filename, fmRead)
  if stream.isNil:
    raise newException(IOError, "Cannot open file for reading: " & filename)
  try:
    result = readTinyVGBinary(stream)
  finally:
    stream.close()
