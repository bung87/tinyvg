# Example: Parse all SVG files under examples/gui and render to single HTML canvas
#
# This example demonstrates:
# 1. Loading GUI/Icon SVG files
# 2. Converting them to TinyVG format
# 3. Rendering all icons into a single HTML canvas with grid layout
# 4. Larger icon display suitable for UI element preview

import std/[os, strformat, sequtils]
import tinyvg
import tinyvg/svgconv
import tinyvg/canvas

proc main() =
  ## Parse all SVG files in examples/gui and render to single HTML
  
  let svgDir = "examples/gui"
  let outputFile = "examples/gui_icons.html"
  
  # Find all SVG files
  let svgFiles = toSeq(walkFiles(svgDir / "*.svg"))
  
  if svgFiles.len == 0:
    echo "No SVG files found in ", svgDir
    return
  
  echo &"Found {svgFiles.len} SVG files in {svgDir}"
  
  # Configuration for the grid layout - larger icons for GUI preview
  let iconsPerRow = 3
  let iconSize = 120
  let padding = 40
  let canvasWidth = iconsPerRow * (iconSize + padding) + padding
  let canvasHeight = ((svgFiles.len + iconsPerRow - 1) div iconsPerRow) * (iconSize + padding) + padding
  
  # Collect all documents
  var docs: seq[tuple[filename: string, doc: TinyVGDocument]]
  var totalColors = 0
  var totalCommands = 0
  
  for svgFile in svgFiles:
    try:
      let tvgDoc = loadSvgAsTinyVG(svgFile)
      let filename = svgFile.extractFilename
      docs.add((filename, tvgDoc))
      totalColors += tvgDoc.palette.len
      totalCommands += tvgDoc.commands.len
      echo &"  ✓ Loaded: {filename} ({tvgDoc.palette.len} colors, {tvgDoc.commands.len} commands)"
    except Exception as e:
      echo &"  ✗ Failed to load {svgFile}: {e.msg}"
  
  if docs.len == 0:
    echo "No valid SVG files could be loaded"
    return
  
  let avgColors = totalColors div docs.len
  let avgCommands = totalCommands div docs.len
  
  # Start building HTML
  var html = """<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>GUI Icons - TinyVG Canvas Renderer</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      margin: 20px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
    }
    h1 {
      color: white;
      text-align: center;
      text-shadow: 0 2px 4px rgba(0,0,0,0.2);
      margin-bottom: 10px;
    }
    .subtitle {
      color: rgba(255,255,255,0.9);
      text-align: center;
      margin-bottom: 30px;
    }
    .container {
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    canvas {
      border-radius: 12px;
      background: white;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    }
    .legend {
      margin-top: 30px;
      display: grid;
      grid-template-columns: repeat(""" & $iconsPerRow & """, 1fr);
      gap: 15px;
      max-width: """ & $canvasWidth & """px;
    }
    .legend-item {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 15px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      transition: transform 0.2s, box-shadow 0.2s;
    }
    .legend-item:hover {
      transform: translateY(-3px);
      box-shadow: 0 6px 12px rgba(0,0,0,0.15);
    }
    .legend-item .icon-name {
      font-size: 14px;
      font-weight: 600;
      color: #333;
    }
    .legend-item .icon-path {
      font-size: 11px;
      color: #888;
    }
    .stats {
      margin-top: 30px;
      padding: 20px;
      background: white;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      min-width: 300px;
    }
    .stats h3 {
      margin-top: 0;
      color: #333;
      border-bottom: 2px solid #667eea;
      padding-bottom: 10px;
    }
    .stats table {
      border-collapse: collapse;
      width: 100%;
    }
    .stats td {
      padding: 8px 12px;
      border-bottom: 1px solid #eee;
    }
    .stats td:first-child {
      font-weight: 600;
      color: #666;
    }
    .stats tr:last-child td {
      border-bottom: none;
    }
  </style>
</head>
<body>
  <h1>GUI Icons Gallery</h1>
  <p class="subtitle">TinyVG rendered UI elements from SVG source</p>
  <div class="container">
    <canvas id="iconCanvas" width=""" & $canvasWidth & """ height=""" & $canvasHeight & """></canvas>
    <div class="legend">
"""
  
  # Generate legend items
  for (filename, _) in docs:
    let nameWithoutExt = filename.changeFileExt("")
    html.add "      <div class=\"legend-item\">\n"
    html.add "        <span class=\"icon-name\">" & nameWithoutExt & "</span>\n"
    html.add "        <span class=\"icon-path\">" & filename & "</span>\n"
    html.add "      </div>\n"
  
  html.add """    </div>
    <div class="stats">
      <h3>Rendering Statistics</h3>
      <table>
        <tr><td>Total Icons:</td><td>""" & $docs.len & """</td></tr>
        <tr><td>Canvas Size:</td><td>""" & $canvasWidth & " × " & $canvasHeight & """</td></tr>
        <tr><td>Icon Size:</td><td>""" & $iconSize & " × " & $iconSize & """</td></tr>
        <tr><td>Total Colors:</td><td>""" & $totalColors & """</td></tr>
        <tr><td>Total Commands:</td><td>""" & $totalCommands & """</td></tr>
        <tr><td>Avg Colors/Icon:</td><td>""" & $avgColors & """</td></tr>
        <tr><td>Avg Commands/Icon:</td><td>""" & $avgCommands & """</td></tr>
      </table>
    </div>
  </div>
  <script>
    // SVG Arc to Canvas Bezier helper function
    function renderArc(ctx, x0, y0, rx, ry, phi, largeArc, sweep, x, y) {
      if (rx === 0 || ry === 0) {
        ctx.lineTo(x, y);
        return;
      }
      rx = Math.abs(rx); ry = Math.abs(ry);
      var phiRad = phi * Math.PI / 180;
      var cosPhi = Math.cos(phiRad);
      var sinPhi = Math.sin(phiRad);
      var dx = (x0 - x) / 2;
      var dy = (y0 - y) / 2;
      var x1p = cosPhi * dx + sinPhi * dy;
      var y1p = -sinPhi * dx + cosPhi * dy;
      var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
      if (lambda > 1) {
        var sqrtLambda = Math.sqrt(lambda);
        rx *= sqrtLambda;
        ry *= sqrtLambda;
      }
      var factor = Math.sqrt(Math.max(0, (rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p) / (rx * rx * y1p * y1p + ry * ry * x1p * x1p)));
      if (largeArc === sweep) factor = -factor;
      var cxp = factor * rx * y1p / ry;
      var cyp = -factor * ry * x1p / rx;
      var cx = cosPhi * cxp - sinPhi * cyp + (x0 + x) / 2;
      var cy = sinPhi * cxp + cosPhi * cyp + (y0 + y) / 2;
      var theta1 = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
      var theta2 = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx);
      var deltaTheta = theta2 - theta1;
      if (!sweep && deltaTheta > 0) deltaTheta -= 2 * Math.PI;
      if (sweep && deltaTheta < 0) deltaTheta += 2 * Math.PI;
      var segments = Math.ceil(Math.abs(deltaTheta) / (Math.PI / 2));
      segments = Math.max(1, segments);
      var eta1 = theta1;
      var cosEta = Math.cos(eta1);
      var sinEta = Math.sin(eta1);
      var epX = cosPhi * rx * cosEta - sinPhi * ry * sinEta + cx;
      var epY = sinPhi * rx * cosEta + cosPhi * ry * sinEta + cy;
      var alpha = Math.sin(Math.abs(deltaTheta) / segments / 2) * 4 / 3;
      for (var i = 0; i < segments; i++) {
        var eta2 = eta1 + deltaTheta / segments;
        var cosEta2 = Math.cos(eta2);
        var sinEta2 = Math.sin(eta2);
        var epX2 = cosPhi * rx * cosEta2 - sinPhi * ry * sinEta2 + cx;
        var epY2 = sinPhi * rx * cosEta2 + cosPhi * ry * sinEta2 + cy;
        var dX = -cosPhi * rx * sinEta - sinPhi * ry * cosEta;
        var dY = -sinPhi * rx * sinEta + cosPhi * ry * cosEta;
        var cp1x = epX + alpha * dX;
        var cp1y = epY + alpha * dY;
        dX = -cosPhi * rx * sinEta2 - sinPhi * ry * cosEta2;
        dY = -sinPhi * rx * sinEta2 + cosPhi * ry * cosEta2;
        var cp2x = epX2 - alpha * dX;
        var cp2y = epY2 - alpha * dY;
        ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, epX2, epY2);
        eta1 = eta2;
        cosEta = cosEta2;
        sinEta = sinEta2;
        epX = epX2;
        epY = epY2;
      }
    }

    const canvas = document.getElementById('iconCanvas');
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
    let scaleX = iconSize.float / doc.header.width.float
    let scaleY = iconSize.float / doc.header.height.float
    let nameWithoutExt = filename.changeFileExt("")

    # Generate JavaScript code for this icon
    let renderCommands = renderToCanvasCommands(doc, "ctx")

    html.add "\n    // Render " & filename & "\n"
    html.add "    ctx.save();\n"
    html.add "    ctx.translate(" & $offsetX & ", " & $offsetY & ");\n"
    html.add "    ctx.scale(" & $scaleX & ", " & $scaleY & ");\n"
    html.add renderCommands & "\n"
    html.add "    ctx.restore();\n"
    html.add "\n"
    html.add "    // Draw subtle border and label for " & filename & "\n"
    html.add "    ctx.strokeStyle = '#e0e0e0';\n"
    html.add "    ctx.lineWidth = 1;\n"
    html.add "    ctx.strokeRect(" & $offsetX & ", " & $offsetY & ", " & $iconSize & ", " & $iconSize & ");\n"
    html.add "    ctx.fillStyle = '#666';\n"
    html.add "    ctx.font = '12px sans-serif';\n"
    html.add "    ctx.textAlign = 'center';\n"
    html.add "    ctx.fillText('" & nameWithoutExt & "', " & $(offsetX + iconSize div 2) & ", " & $(offsetY + iconSize + 20) & ");\n"
  
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
  echo &"  - Icon size: {iconSize}×{iconSize}"
  echo &"  - Open in browser to view"

when isMainModule:
  main()
