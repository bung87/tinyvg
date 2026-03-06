# Example: Parse all SVG files under examples/lang and render to single HTML canvas
#
# This example demonstrates:
# 1. Loading multiple SVG files
# 2. Converting them to TinyVG format
# 3. Rendering all icons into a single HTML canvas with grid layout

import std/[os, strformat, sequtils]
import tinyvg
import tinyvg/svg
import tinyvg/svgconv
import tinyvg/canvas

proc main() =
  ## Parse all SVG files in examples/lang and render to single HTML
  
  let svgDir = "examples/lang"
  let outputFile = "examples/lang_icons.html"
  
  # Find all SVG files
  let svgFiles = toSeq(walkFiles(svgDir / "*.svg"))
  
  if svgFiles.len == 0:
    echo "No SVG files found in ", svgDir
    return
  
  echo &"Found {svgFiles.len} SVG files"
  
  # Configuration for the grid layout
  let iconsPerRow = 5
  let iconSize = 100
  let padding = 20
  let canvasWidth = iconsPerRow * (iconSize + padding) + padding
  let canvasHeight = ((svgFiles.len + iconsPerRow - 1) div iconsPerRow) * (iconSize + padding) + padding
  
  # Start building HTML
  var html = &"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Programming Language Icons - TinyVG Canvas Renderer</title>
  <style>
    body {{
      font-family: Arial, sans-serif;
      margin: 20px;
      background: #f5f5f5;
    }}
    h1 {{
      color: #333;
      text-align: center;
    }}
    .container {{
      display: flex;
      flex-direction: column;
      align-items: center;
    }}
    canvas {{
      border: 2px solid #333;
      background: white;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }}
    .legend {{
      margin-top: 20px;
      display: grid;
      grid-template-columns: repeat({iconsPerRow}, 1fr);
      gap: 10px;
      max-width: {canvasWidth}px;
    }}
    .legend-item {{
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 8px;
      background: white;
      border-radius: 4px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      font-size: 12px;
      color: #666;
    }}
    .stats {{
      margin-top: 20px;
      padding: 15px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }}
    .stats h3 {{
      margin-top: 0;
      color: #333;
    }}
    .stats table {{
      border-collapse: collapse;
      width: 100%;
    }}
    .stats td {{
      padding: 5px 10px;
      border-bottom: 1px solid #eee;
    }}
    .stats td:first-child {{
      font-weight: bold;
      color: #666;
    }}
  </style>
</head>
<body>
  <h1>Programming Language Icons</h1>
  <div class="container">
    <canvas id="iconCanvas" width="{canvasWidth}" height="{canvasHeight}"></canvas>
    <div class="legend">
"""
  
  # Collect all documents and generate legend
  var docs: seq[tuple[filename: string, doc: TinyVGDocument]]
  var totalColors = 0
  var totalCommands = 0
  
  for i, svgFile in svgFiles:
    try:
      let tvgDoc = loadSvgAsTinyVG(svgFile)
      let filename = svgFile.extractFilename
      docs.add((filename, tvgDoc))
      totalColors += tvgDoc.palette.len
      totalCommands += tvgDoc.commands.len
      
      # Add to legend
      html.add &"""      <div class="legend-item">{filename}</div>
"""
      
      echo &"  ✓ Loaded: {filename} ({tvgDoc.palette.len} colors, {tvgDoc.commands.len} commands)"
    except Exception as e:
      echo &"  ✗ Failed to load {svgFile}: {e.msg}"
  
  html.add """    </div>
    <div class="stats">
      <h3>Rendering Statistics</h3>
      <table>
"""

  html.add &"""        <tr><td>Total Icons:</td><td>{docs.len}</td></tr>
        <tr><td>Canvas Size:</td><td>{canvasWidth} × {canvasHeight}</td></tr>
        <tr><td>Total Colors:</td><td>{totalColors}</td></tr>
        <tr><td>Total Commands:</td><td>{totalCommands}</td></tr>
        <tr><td>Avg Colors/Icon:</td><td>{totalColors div docs.len}</td></tr>
        <tr><td>Avg Commands/Icon:</td><td>{totalCommands div docs.len}</td></tr>
      </table>
    </div>
  </div>
  <script>
    // SVG Arc to Canvas helper function using native ellipse method
    function renderArc(ctx, x0, y0, rx, ry, phi, largeArc, sweep, x, y) {{
      if (rx === 0 || ry === 0) {{
        ctx.lineTo(x, y);
        return;
      }}
      rx = Math.abs(rx); ry = Math.abs(ry);
      var phiRad = phi * Math.PI / 180;
      var cosPhi = Math.cos(phiRad);
      var sinPhi = Math.sin(phiRad);
      var dx = (x0 - x) / 2;
      var dy = (y0 - y) / 2;
      var x1p = cosPhi * dx + sinPhi * dy;
      var y1p = -sinPhi * dx + cosPhi * dy;
      var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
      if (lambda > 1) {{
        var sqrtLambda = Math.sqrt(lambda);
        rx *= sqrtLambda;
        ry *= sqrtLambda;
      }}
      var factor = Math.sqrt(Math.max(0, (rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p) / (rx * rx * y1p * y1p + ry * ry * x1p * x1p)));
      if (largeArc === sweep) factor = -factor;
      var cxp = factor * rx * y1p / ry;
      var cyp = -factor * ry * x1p / rx;
      var cx = cosPhi * cxp - sinPhi * cyp + (x0 + x) / 2;
      var cy = sinPhi * cxp + cosPhi * cyp + (y0 + y) / 2;
      var theta1 = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
      var theta2 = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx);
      ctx.ellipse(cx, cy, rx, ry, phiRad, theta1, theta2, !sweep);
    }}
"""
  
  html.add """    const canvas = document.getElementById('iconCanvas');
    const ctx = canvas.getContext('2d');
    
    // Clear canvas with white background
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
"""

  # Generate JavaScript for each icon
  for i, (filename, doc) in docs:
    let row = i div iconsPerRow
    let col = i mod iconsPerRow
    let offsetX = padding + col * (iconSize + padding)
    let offsetY = padding + row * (iconSize + padding)

    # Generate JavaScript code for this icon (just the commands, no setup)
    let renderCommands = renderToCanvasCommands(doc, "ctx")

    # Wrap with save/restore and translate to position
    html.add &"""
    // Render {filename}
    ctx.save();
    ctx.translate({offsetX}, {offsetY});
    ctx.scale({iconSize.float / doc.header.width.float}, {iconSize.float / doc.header.height.float});
{renderCommands}
    ctx.restore();

    // Draw border for {filename}
    ctx.strokeStyle = '#ddd';
    ctx.lineWidth = 1;
    ctx.strokeRect({offsetX}, {offsetY}, {iconSize}, {iconSize});
"""
  
  # Close HTML
  html.add """  </script>
</body>
</html>
"""
  
  # Write output file
  writeFile(outputFile, html)
  
  echo &"\n✓ Generated: {outputFile}"
  echo &"  - Canvas size: {canvasWidth} × {canvasHeight}"
  echo &"  - Icons rendered: {docs.len}"
  echo &"  - Open in browser to view"

when isMainModule:
  main()
