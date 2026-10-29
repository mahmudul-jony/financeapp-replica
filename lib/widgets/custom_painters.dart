import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_constants.dart';

class AnalyticsChartPainter extends CustomPainter {
  const AnalyticsChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = height * (i / 4);
      var startX = 0.0;
      while (startX < width) {
        canvas.drawLine(Offset(startX, y), Offset(startX + 2, y), gridPaint);
        startX += 6;
      }
    }

    final path = Path();
    path.moveTo(0, height * 0.75);
    path.cubicTo(width * 0.2, height * 0.8, width * 0.25, height * 0.3, width * 0.4, height * 0.35);
    path.cubicTo(width * 0.55, height * 0.4, width * 0.65, height * 0.9, width * 0.8, height * 0.5);
    path.cubicTo(width * 0.9, height * 0.3, width * 0.95, height * 0.4, width, height * 0.2);

    final fillPath = Path.from(path);
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.graphPurple.withOpacity(0.2),
          AppColors.graphPurple.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.graphPurple
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final List<Offset> points = [
      Offset(width * 0.4, height * 0.35),
      Offset(width * 0.8, height * 0.5),
      Offset(width, height * 0.2),
    ];

    final dotPaint = Paint()..color = AppColors.graphPurple;
    final dotOutlinePaint = Paint()..color = Colors.white;

    for (final point in points) {
      canvas.drawCircle(point, 5, dotOutlinePaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandMarkPainter extends CustomPainter {
  final Color accent;
  const BrandMarkPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final accentPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, size.width * 0.48, basePaint);

    for (var i = 0; i < 4; i++) {
      final angle = (math.pi / 2) * i;
      final offset = Offset(math.cos(angle), math.sin(angle)) * size.width * 0.18;
      canvas.drawCircle(center + offset, size.width * 0.16, accentPaint);
    }

    canvas.drawCircle(center, size.width * 0.11, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant BrandMarkPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class DashedLinePainter extends CustomPainter {
  const DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE4E4E4)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    const dashWidth = 6.0;
    const dashGap = 5.0;
    var startX = 0.0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArcGaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  const ArcGaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    
    final bgPaint = Paint()
      ..color = AppColors.borderGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, math.pi, false, bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, math.pi * percentage, false, progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcGaugePainter oldDelegate) => oldDelegate.percentage != percentage;
}

class ModernBarChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const ModernBarChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final bgPaint = Paint()..color = AppColors.borderGrey..style = PaintingStyle.fill;
    
    final double barWidth = size.width / (values.length * 2 - 1);
    
    for (int i = 0; i < values.length; i++) {
      final double x = i * barWidth * 2;
      final double barHeight = size.height * values[i];
      
      // Background bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, size.height), const Radius.circular(4)),
        bgPaint,
      );
      
      // Progress bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ModernBarChartPainter oldDelegate) => oldDelegate.values != values;
}

class DonutChartPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color? backgroundColor;
  final double strokeWidth;

  const DonutChartPainter({
    required this.percentage,
    required this.color,
    this.backgroundColor,
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final bgPaint = Paint()
      ..color = backgroundColor ?? AppColors.borderGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    if (percentage > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * percentage.clamp(0.0, 1.0), false, progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      oldDelegate.percentage != percentage ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
