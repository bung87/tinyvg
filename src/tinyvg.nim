# TinyVG library

## Imports and Exports

import tinyvg/core
import tinyvg/reader
import tinyvg/writer
import tinyvg/binary
import tinyvg/canvas
import tinyvg/svg
import tinyvg/svgconv

export core
export reader
export writer
export binary
export canvas
export svg
export svgconv

## Usage Example

# Example of creating a TinyVG document
# var doc = initTinyVGDocument(400, 768, 1.0)
# var red = doc.addColor(1.0, 0.0, 0.0)
# var green = doc.addColor(0.0, 1.0, 0.0)
# doc.addFillRectangle(25, 25, 100, 15, red)
# doc.addOutlineFillRectangle(25, 105, 100, 15, red, green, 2.5)
# writeTinyVG(doc, "example.tvg")

# Example of reading a TinyVG document
# var doc = readTinyVG("example.tvg")
# echo "Document width: ", doc.header.width
# echo "Document height: ", doc.header.height
# echo "Number of commands: ", doc.commands.len
