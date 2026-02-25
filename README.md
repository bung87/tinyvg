# TinyVG

A Nim library for reading and writing TinyVG (Tiny Vector Graphics) files.

[TinyVG](https://tinyvg.tech/) is a compact, text-based vector graphics format designed for embedded systems and resource-constrained environments.

## Features

- **Read** TinyVG text format files
- **Write** TinyVG text format files
- **Create** vector graphics programmatically
- **Round-trip** support (read → modify → write)
- Support for all TinyVG commands:
  - Fill rectangles
  - Outline fill rectangles
  - Draw lines, line loops, line strips
  - Fill polygons
  - Draw and fill paths (with Bezier curves, arcs)
  - Text hints
- Flexible color styles: flat, linear gradient, radial gradient
- Fractional scale values (e.g., `1/32`)

## Installation

Install via nimble:

```bash
  nimble install tinyvg
  ```

Or add to your `.nimble` file:

```nim
requires "tinyvg >= 0.1.0"
```

## Quick Start

### Creating a TinyVG Document

```nim
import tinyvg

# Create a new document (width, height, scale)
var doc = initTinyVGDocument(400, 768, 1.0)

# Add colors to the palette
var red = doc.addColor(1.0, 0.0, 0.0)     # RGB
var green = doc.addColor(0.0, 1.0, 0.0)   # RGB
var blue = doc.addColor(0.0, 0.0, 1.0, 0.5)  # RGBA with alpha

# Add a filled rectangle
doc.addFillRectangle(25, 25, 100, 15, red)

# Add an outlined filled rectangle
doc.addOutlineFillRectangle(25, 105, 100, 15, red, green, 2.5)

# Write to file
writeTinyVG(doc, "example.tvg")
```

### Reading a TinyVG Document

```nim
import tinyvg

# Read from file
var doc = readTinyVG("example.tvg")

# Access document properties
echo "Width: ", doc.header.width
echo "Height: ", doc.header.height
echo "Colors: ", doc.palette.len
echo "Commands: ", doc.commands.len
```

### Parsing from String

```nim
import tinyvg

var tvgText = """
(tvg 1
  (400 768 1/32 u8888 default)
  (
    (1.000 0.000 0.000)
    (0.000 1.000 0.000)
  )
  (
    (
      fill_rectangles
      (flat 0)
      (
        (25 25 100 15)
      )
    )
  )
)
"""

var doc = parseTinyVG(tvgText)
```

## API Reference

### Document Creation

- `initTinyVGDocument(width, height, scale = 1.0)` - Create a new document
- `addColor(r, g, b, a = 1.0)` - Add a color to the palette, returns color index

### Drawing Commands

- `addFillRectangle(x, y, width, height, colorIndex)` - Add filled rectangle
- `addOutlineFillRectangle(x, y, width, height, fillColor, lineColor, lineWidth)` - Add outlined filled rectangle

### File I/O

- `readTinyVG(filename)` - Read a TinyVG file
- `writeTinyVG(doc, filename)` - Write a document to file
- `parseTinyVG(text)` - Parse TinyVG text format string
- `writeTinyVG(doc)` - Serialize document to string

### Data Types

#### TinyVGDocument
- `header`: Document metadata (version, width, height, scale, format)
- `palette`: Sequence of colors
- `commands`: Drawing commands

#### TinyVGColor
- `r`, `g`, `b`, `a`: Float values (0.0 - 1.0)

#### TinyVGStyle
- `kind`: `flat`, `linear`, or `radial`
- `flatColorIndex`: For flat colors
- `linearStartPoint`, `linearEndPoint`, `linearStartColorIndex`, `linearEndColorIndex`: For linear gradients
- `radialStartPoint`, `radialEndPoint`, `radialStartColorIndex`, `radialEndColorIndex`: For radial gradients

## TinyVG Format

TinyVG files use a Lisp-like syntax:

```lisp
(tvg 1                              ; Version 1
  (400 768 1/32 u8888 default)      ; Width, Height, Scale, Format, Precision
  (                                 ; Color palette
    (1.000 0.000 0.000)             ; Red
    (0.000 1.000 0.000)             ; Green
  )
  (                                 ; Commands
    (
      fill_rectangles               ; Command type
      (flat 0)                      ; Style (flat, color index 0)
      (                             ; Rectangles
        (25 25 100 15)              ; x, y, width, height
      )
    )
  )
)
```

## Testing

Run the test suite:

```bash
nimble test
```

## License

MIT License - see LICENSE file for details.

## See Also

- [TinyVG Specification](https://tinyvg.tech/)
- [TinyVG GitHub](https://github.com/TinyVG)
