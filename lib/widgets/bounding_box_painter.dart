import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> recognitions;
  final Size cameraSize;
  final Size screenSize;

  BoundingBoxPainter(this.recognitions, this.cameraSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width;
    final double scaleY = size.height;

    for (var result in recognitions) {
      final rectInfo = result['rect'];
      final x = rectInfo['x'] * scaleX;
      final y = rectInfo['y'] * scaleY;
      final w = rectInfo['w'] * scaleX;
      final h = rectInfo['h'] * scaleY;

      final rect = Rect.fromLTWH(x, y, w, h);
      
      final paintRect = Paint()
        ..color = AppTheme.errorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
        
      final paintBackground = Paint()
        ..color = AppTheme.errorColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, paintBackground);
      canvas.drawRect(rect, paintRect);

      // Draw Label
      const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      );
      
      final label = '${result['detectedClass']} ${(result['confidenceInClass'] * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      
      // Draw Label Background
      final labelBgRect = Rect.fromLTWH(
        x, 
        y - textPainter.height - 8, 
        textPainter.width + 16, 
        textPainter.height + 8
      );
      final labelBgPaint = Paint()..color = AppTheme.errorColor;
      canvas.drawRect(labelBgRect, labelBgPaint);
      
      textPainter.paint(canvas, Offset(x + 8, y - textPainter.height - 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint for live feed
  }
}
