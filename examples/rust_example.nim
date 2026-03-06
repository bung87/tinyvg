# Example: Rust SVG to TinyVG Conversion and Rendering
#
# This example demonstrates:
# 1. Loading the Rust logo SVG
# 2. Converting it to TinyVG format
# 3. Rendering it to HTML canvas
# 4. Saving the TinyVG binary file
# 5. Comparing file sizes

import std/[os, strformat, math]
import tinyvg
import tinyvg/svgconv
import tinyvg/canvas
import tinyvg/binary

proc main() =
  ## Rust logo conversion and rendering example
  
  let svgFile = "examples/lang/rust.svg"
  let tvgFile = "examples/rust.tvg"
  let htmlFile = "examples/rust_render.html"
  
  echo "=== Rust SVG to TinyVG Example ==="
  echo ""
  
  # Check if SVG file exists
  if not fileExists(svgFile):
    echo &"Error: SVG file not found: {svgFile}"
    return
  
  echo &"1. Loading SVG: {svgFile}"
  
  # Load and convert SVG to TinyVG
  var tvgDoc: TinyVGDocument
  try:
    tvgDoc = loadSvgAsTinyVG(svgFile)
    echo &"   ✓ Converted successfully"
    echo &"   - Canvas size: {tvgDoc.header.width} x {tvgDoc.header.height}"
    echo &"   - Scale: {tvgDoc.header.scale}"
    echo &"   - Colors in palette: {tvgDoc.palette.len}"
    echo &"   - Commands: {tvgDoc.commands.len}"
  except Exception as e:
    echo &"   ✗ Conversion failed: {e.msg}"
    return
  
  echo ""
  echo &"2. Saving TinyVG binary: {tvgFile}"
  
  # Save TinyVG binary file
  var svgSize, tvgSize: int64
  var savings: float
  try:
    writeTinyVGBinary(tvgDoc, tvgFile)
    svgSize = getFileSize(svgFile)
    tvgSize = getFileSize(tvgFile)
    savings = (1.0 - float(tvgSize) / float(svgSize)) * 100.0
    echo &"   ✓ Saved successfully"
    echo &"   - SVG size: {svgSize} bytes"
    echo &"   - TinyVG size: {tvgSize} bytes"
    echo &"   - Space savings: {savings:.1f}%"
  except Exception as e:
    echo &"   ✗ Save failed: {e.msg}"
    return
  
  echo ""
  echo &"3. Rendering to HTML: {htmlFile}"
  
  # Render to HTML canvas
  try:
    let canvasWidth = 400
    let canvasHeight = 400
    
    # Generate the TinyVG rendering JavaScript code (only commands, no canvas setup)
    let renderCode = renderToCanvasCommands(tvgDoc, "ctx")
    
    var html = &"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Rust Logo - TinyVG Render</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      margin: 0;
      padding: 40px;
      background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
    }}
    h1 {{
      color: white;
      margin-bottom: 10px;
      text-shadow: 0 2px 4px rgba(0,0,0,0.3);
    }}
    .subtitle {{
      color: rgba(255,255,255,0.8);
      margin-bottom: 30px;
    }}
    .container {{
      display: flex;
      gap: 40px;
      flex-wrap: wrap;
      justify-content: center;
    }}
    .card {{
      background: white;
      border-radius: 16px;
      padding: 30px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
      text-align: center;
    }}
    .card h2 {{
      margin-top: 0;
      color: #333;
      font-size: 18px;
    }}
    canvas {{
      border: 2px solid #e0e0e0;
      border-radius: 8px;
      background: white;
    }}
    .stats {{
      margin-top: 30px;
      background: white;
      border-radius: 16px;
      padding: 25px 40px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
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
      padding: 8px 20px;
      border-bottom: 1px solid #eee;
    }}
    .stats td:first-child {{
      font-weight: bold;
      color: #666;
      text-align: right;
    }}
    .stats td:last-child {{
      color: #333;
      text-align: left;
    }}
    .badge {{
      display: inline-block;
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: bold;
      margin-left: 10px;
    }}
    .badge-success {{
      background: #4caf50;
      color: white;
    }}
  </style>
</head>
<body>
  <h1>Rust Logo</h1>
  <p class="subtitle">SVG to TinyVG Conversion Example</p>
  
  <div class="container">
    <div class="card">
      <h2>Original SVG</h2>
      <img src="lang/rust.svg" width="{canvasWidth}" height="{canvasHeight}" alt="Rust SVG">
    </div>
    
    <div class="card">
      <h2>TinyVG Rendered</h2>
      <canvas id="tvgCanvas" width="{canvasWidth}" height="{canvasHeight}"></canvas>
    </div>
  </div>
  
  <div class="stats">
    <h3>Conversion Statistics</h3>
    <table>
      <tr>
        <td>Canvas Size:</td>
        <td>{tvgDoc.header.width} x {tvgDoc.header.height}</td>
      </tr>
      <tr>
        <td>Scale Factor:</td>
        <td>{tvgDoc.header.scale}</td>
      </tr>
      <tr>
        <td>Color Palette:</td>
        <td>{tvgDoc.palette.len} colors</td>
      </tr>
      <tr>
        <td>Draw Commands:</td>
        <td>{tvgDoc.commands.len}</td>
      </tr>
      <tr>
        <td>SVG File Size:</td>
        <td>{svgSize} bytes</td>
      </tr>
      <tr>
        <td>TinyVG File Size:</td>
        <td>{tvgSize} bytes <span class="badge badge-success">{savings:.1f}% smaller</span></td>
      </tr>
    </table>
  </div>
  
  <script>
    // TinyVG rendering code
    const canvas = document.getElementById('tvgCanvas');
    const ctx = canvas.getContext('2d');
    
    // Set white background
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Scale to fit canvas while maintaining aspect ratio
    const scaleX = canvas.width / {tvgDoc.header.width};
    const scaleY = canvas.height / {tvgDoc.header.height};
    const scale = Math.min(scaleX, scaleY) * 0.9;
    
    const offsetX = (canvas.width - {tvgDoc.header.width} * scale) / 2;
    const offsetY = (canvas.height - {tvgDoc.header.height} * scale) / 2;
"""
    
    # Add renderArc helper function
    html.add("""
    
    // Add renderArc helper function for SVG arc rendering
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
      ctx.ellipse(cx, cy, rx, ry, phiRad, theta1, theta2, !sweep);
    }
    
    ctx.save();
    ctx.translate(offsetX, offsetY);
    ctx.scale(scale, scale);
""")
    
    # Add the render code
    html.add(renderCode)
    
    html.add("""
    ctx.restore();
  </script>
</body>
</html>""")
    
    writeFile(htmlFile, html)
    echo &"   ✓ HTML rendered successfully"
    echo &"   - Canvas: {canvasWidth}x{canvasHeight}"
    echo &"   - Open {htmlFile} in a browser to view"
    
  except Exception as e:
    echo &"   ✗ Render failed: {e.msg}"
    return
  
  echo ""
  echo "=== Example Complete ==="
  echo &"Files generated:"
  echo &"  - TinyVG: {tvgFile}"
  echo &"  - HTML:   {htmlFile}"
  echo ""
  echo "Open the HTML file in a browser to see the rendered result."

when isMainModule:
  main()
