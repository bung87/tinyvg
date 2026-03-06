# SVG to TinyVG Converter Limitations

This document describes the current limitations of the `svgconv` module based on the TinyVG specification. While the converter handles common SVG constructs, several advanced features from both SVG and TinyVG specifications are not yet fully supported.

## Recent Improvements (March 2026)

### Path Command Support - COMPLETE
All SVG path commands are now fully supported:
- Arc commands (`A`, `a`) - Converted to TinyVG arc circle/ellipse nodes
- Quadratic bezier (`Q`, `q`) - Converted to TinyVG quadratic bezier nodes
- Smooth cubic bezier (`S`, `s`) - Properly converted
- Smooth quadratic bezier (`T`, `t`) - Properly converted

### Multiple Subpath Support
SVG paths with multiple `M` (move) commands are now correctly handled:
- Each subpath is properly closed before starting a new one
- Subpath starting points are correctly tracked
- Fill rules (evenodd) work correctly across subpaths

### Canvas Rendering Improvements
- Zero-length line segments are now skipped (reduces unnecessary draw calls)
- Subpath start points are properly tracked for correct close path behavior
- Native canvas `ellipse()` method is used for smooth arc rendering

## Currently Supported Features

### SVG Elements
- `<path>` - Full path data support including move, line, cubic bezier, quadratic bezier, arc (circle/ellipse), and close path commands
- `<rect>` - Rectangles with fill and stroke
- `<circle>` - Circles (converted to TinyVG arc circles)
- `<ellipse>` - Ellipses (converted to TinyVG arc ellipses)
- `<line>` - Simple lines
- `<polyline>` - Connected line segments
- `<polygon>` - Closed polygons
- `<g>` - Groups (recursively processed)

### SVG Attributes
- `fill` - Solid colors (hex, named colors)
- `stroke` - Stroke colors
- `stroke-width` - Stroke width
- `opacity` - Parsed but not fully applied
- `transform` - Parsed but not applied
- `clip-path` - Detected and cleared (not rendered)

### TinyVG Commands Generated
- Fill Polygon
- Fill Rectangles
- Fill Path (with multiple subpath support)
- Draw Lines
- Draw Line Loop
- Draw Line Strip
- Draw Line Path
- Outline Fill Polygon
- Outline Fill Rectangles
- Outline Fill Path (with multiple subpath support)

## Limitations and Missing Features

### 1. Gradient Support (Partial)

**Specification:** TinyVG supports Linear and Radial 2-point gradients as fill styles.

**Current Status:** Basic gradient reference parsing exists but full gradient conversion is not implemented.

**Missing:**
- Linear gradient conversion from SVG `<linearGradient>` to TinyVG linear gradient style
- Radial gradient conversion from SVG `<radialGradient>` to TinyVG radial gradient style
- Gradient stop interpolation
- Gradient transform handling
- Proper gradient color table indexing

**Workaround:** Currently falls back to first stop color for gradient references.

### 2. Path Commands

**Specification:** TinyVG supports 8 path instruction types:
- Line (0)
- Horizontal Line (1)
- Vertical Line (2)
- Cubic Bezier (3)
- Arc Circle (4)
- Arc Ellipse (5)
- Close Path (6)
- Quadratic Bezier (7)

**Current Status:** SVG path parsing supports all SVG path commands.

**Supported SVG Path Commands:**
- Move (`M`, `m`) - Full support with multiple subpath handling
- Line (`L`, `l`) - Full support
- Horizontal line (`H`, `h`) - Full support
- Vertical line (`V`, `v`) - Full support
- Cubic bezier (`C`, `c`) - Full support
- Smooth cubic bezier (`S`, `s`) - Converted to cubic bezier
- Quadratic bezier (`Q`, `q`) - Full support
- Smooth quadratic bezier (`T`, `t`) - Converted to quadratic bezier
- Arc commands (`A`, `a`) - Converted to TinyVG arc circle/ellipse
- Close path (`Z`, `z`) - Full support with proper subpath handling

**Note:** All SVG path commands are now supported and properly converted to their TinyVG equivalents.

### 3. Text Support

**Specification:** TinyVG includes a `text hint path` command (index 11) for accessibility and text selection metadata.

**Current Status:** Not implemented.

**Missing:**
- SVG `<text>` element parsing
- SVG `<tspan>` element parsing
- Font metrics calculation
- Text positioning and layout
- Text hint command generation

### 4. Transformations

**Specification:** SVG uses a transform matrix system for positioning, scaling, rotating elements.

**Current Status:** Parsed but not applied.

**Missing:**
- Matrix transformation application
- Translate, scale, rotate transforms
- Skew transforms
- Transform stacking for nested groups
- ViewBox coordinate transformation

**Impact:** SVGs using transforms may render incorrectly or in wrong positions.

### 5. Coordinate Precision

**Specification:** TinyVG supports three coordinate ranges:
- Default (16-bit coordinates)
- Reduced (8-bit coordinates)
- Enhanced (32-bit coordinates)

**Current Status:** Always uses default 16-bit coordinates with scale factor 1.0.

**Missing:**
- Automatic coordinate range detection
- Optimal scale factor calculation
- Reduced coordinate range for small images
- Enhanced coordinate range for large/precise images

### 6. Color Encodings

**Specification:** TinyVG supports four color encodings:
- RGBA 8888 (4 bytes per color)
- RGB 565 (2 bytes per color)
- RGBA F32 (16 bytes per color)
- Custom (undefined)

**Current Status:** Always uses RGBA 8888.

**Missing:**
- RGB 565 encoding option
- RGBA F32 encoding option
- Automatic color encoding selection based on image requirements

### 7. Advanced SVG Features

**Not Supported:**
- `<defs>` and `<use>` - Symbol definitions and reuse
- `<symbol>` - Symbol definitions
- `<mask>` - Masking
- `<pattern>` - Pattern fills
- `<image>` - Embedded images
- `<filter>` - Filter effects (blur, shadows, etc.)
- `<marker>` - Line markers
- `<mask>` - Masking
- CSS styles - Internal or external CSS
- Presentation attributes - Style attributes on elements

### 8. Fill Rules

**Specification:** SVG supports `fill-rule` attribute (`nonzero`, `evenodd`). TinyVG uses even-odd rule for paths.

**Current Status:** Even-odd rule is used for path filling, matching TinyVG specification.

**Note:** SVGs using `fill-rule="nonzero"` may render differently.

### 9. Stroke Properties

**Current Status:** Basic stroke color and width supported.

**Missing:**
- Stroke dash patterns (`stroke-dasharray`, `stroke-dashoffset`)
- Stroke line caps (`stroke-linecap`: butt, round, square)
- Stroke line joins (`stroke-linejoin`: miter, round, bevel)
- Stroke miter limit (`stroke-miterlimit`)

### 10. Clipping and Masking

**Current Status:** Clip-path attributes are detected and those elements are cleared (not rendered).

**Missing:**
- Proper clip-path application
- Mask support
- Alpha masking

### 11. ViewBox and Aspect Ratio

**Current Status:** ViewBox is parsed but not applied for coordinate transformation.

**Missing:**
- ViewBox to viewport mapping
- Preserve aspect ratio handling (`preserveAspectRatio` attribute)
- Slice vs meet alignment

### 12. Animation

**Not Supported:**
- SMIL animations (`<animate>`, `<animateTransform>`, etc.)
- CSS animations
- JavaScript animations

## Recommendations for SVG Preparation

To ensure best conversion results:

1. **Flatten transforms** - Apply all transforms before conversion
2. **Convert arcs** - Approximate arc commands with bezier curves
3. **Simplify paths** - Remove unnecessary commands
4. **Avoid gradients** - Use solid colors instead
5. **Remove text** - Convert text to paths
6. **Remove effects** - Remove filters, masks, and patterns
7. **Set explicit sizes** - Ensure width and height are set
8. **Avoid CSS** - Use inline attributes instead

## Future Work

Priority features for implementation:

1. **Arc command support** - Convert SVG arcs to TinyVG arc circle/ellipse
2. **Gradient support** - Full linear and radial gradient conversion
3. **Transform application** - Apply SVG transforms during conversion
4. **Quadratic bezier** - Support quadratic bezier commands
5. **Text conversion** - Convert text to paths or text hints
6. **Coordinate optimization** - Automatic coordinate range selection
