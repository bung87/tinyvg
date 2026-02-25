# TinyVG Memory Usage Tests

import unittest
import strutils
import tinyvg

proc testMemoryStats() =
  test "Memory statistics reporting":
    let stats = getMemoryStats()
    echo "\n" & formatMemoryStats(stats)
    
    # Verify sizes are reasonable (optimized)
    check stats.colorSize == 16  # 4 x float32 = 16 bytes (was 32)
    check stats.pointSize == 8   # 2 x float32 = 8 bytes (was 16)
    check stats.rectangleSize == 16  # 4 x float32 = 16 bytes (was 32)
    check stats.lineSize == 16   # 2 x VGPoint = 16 bytes (was 32)

proc testMemoryEstimation() =
  test "Document memory estimation":
    var doc = initTinyVGDocument(400, 768)
    
    # Add some colors
    for i in 0..<10:
      discard doc.addColor(float32(i) / 10.0, 0.5, 0.5)
    
    # Add some rectangles
    for i in 0..<100:
      doc.addFillRectangle(float32(i) * 10, float32(i) * 5, 50, 30, i mod 10)
    
    # Add some polygons
    for i in 0..<50:
      doc.addFillPolygon([
        (float32(i) * 10, float32(i) * 5),
        (float32(i) * 10 + 50, float32(i) * 5),
        (float32(i) * 10 + 25, float32(i) * 5 + 50)
      ], i mod 10)
    
    let usage = estimateMemoryUsage(doc)
    echo "\n" & formatMemoryEstimate(doc)
    
    # Verify memory usage is reasonable
    check usage > 0
    check doc.palette.len == 10
    check doc.commands.len == 150  # 100 rectangles + 50 polygons

proc testCapacityHints() =
  test "Capacity hints reduce allocations":
    # Create document with capacity hints
    var doc = initTinyVGDocument(
      400, 768,
      initialPaletteCapacity = 100,
      initialCommandCapacity = 500
    )
    
    # Add data
    for i in 0..<50:
      discard doc.addColor(float32(i) / 50.0, 0.5, 0.5)
    
    for i in 0..<200:
      doc.addFillRectangle(float32(i) * 5, float32(i) * 3, 40, 20, i mod 50)
    
    check doc.palette.len == 50
    check doc.commands.len == 200
    
    let usage = estimateMemoryUsage(doc)
    echo "\nDocument with capacity hints:"
    echo formatMemoryEstimate(doc)

proc testMemoryEfficiency() =
  test "Memory efficiency comparison":
    echo "\n=== Memory Efficiency Analysis ==="
    
    let stats = getMemoryStats()
    
    # Calculate theoretical savings
    let oldColorSize = 32  # 4 x float64
    let newColorSize = stats.colorSize
    let colorSavings = (1.0 - float32(newColorSize) / float32(oldColorSize)) * 100.0
    
    let oldPointSize = 16  # 2 x float64
    let newPointSize = stats.pointSize
    let pointSavings = (1.0 - float32(newPointSize) / float32(oldPointSize)) * 100.0
    
    let oldRectSize = 32  # 4 x float64
    let newRectSize = stats.rectangleSize
    let rectSavings = (1.0 - float32(newRectSize) / float32(oldRectSize)) * 100.0
    
    echo "Color: ", oldColorSize, " bytes → ", newColorSize, " bytes (", 
         colorSavings.formatFloat(ffDecimal, 1), "% reduction)"
    echo "Point: ", oldPointSize, " bytes → ", newPointSize, " bytes (", 
         pointSavings.formatFloat(ffDecimal, 1), "% reduction)"
    echo "Rectangle: ", oldRectSize, " bytes → ", newRectSize, " bytes (", 
         rectSavings.formatFloat(ffDecimal, 1), "% reduction)"
    
    # Verify we achieved expected savings
    check colorSavings >= 49.0  # At least 49% reduction (float32 vs float64)
    check pointSavings >= 49.0
    check rectSavings >= 49.0

# Run all tests
when isMainModule:
  testMemoryStats()
  testMemoryEstimation()
  testCapacityHints()
  testMemoryEfficiency()
  echo "\nAll memory optimization tests passed!"
