import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 6 rütbenin amblemi — LoL rank crest'leri tarzı, geometrik ve bir set gibi
/// okunan. Tek [CustomPainter], rütbeye (1–6) göre kademeli detaylanır:
/// altıgen çerçeve + pusula yıldızı; üst rütbelerde çift çerçeve, köşe
/// çivileri, iç halka. Maskot/çizgi film yok — nesne.
class RankEmblem extends StatelessWidget {
  final int rank; // 1..6
  final int colorHex;
  final double size;

  const RankEmblem({
    super.key,
    required this.rank,
    required this.colorHex,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RankEmblemPainter(rank: rank, color: Color(colorHex)),
      ),
    );
  }
}

class _RankEmblemPainter extends CustomPainter {
  final int rank;
  final Color color;

  _RankEmblemPainter({required this.rank, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    final stroke = 1.5 + rank * 0.22;
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.10);
    final glyphPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final glyphSoft = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.55);

    // --- Altıgen çerçeve (sivri tepe) ---
    final outer = _hexPath(c, r - stroke, pointyTop: true);
    canvas.drawPath(outer, fillPaint);
    canvas.drawPath(outer, framePaint);

    // Rütbe 4+ : ikinci iç çerçeve
    if (rank >= 4) {
      final inner = _hexPath(c, r - stroke - r * 0.13, pointyTop: true);
      canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.6
          ..color = color.withValues(alpha: 0.6),
      );
    }

    // Rütbe 5+ : köşe çivileri
    if (rank >= 5) {
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final p = c + Offset(math.cos(a), math.sin(a)) * (r - stroke);
        canvas.drawCircle(p, stroke * 0.9, glyphPaint);
      }
    }

    // Rütbe 6 : iç halka
    if (rank >= 6) {
      canvas.drawCircle(
        c,
        r * 0.30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.7
          ..color = color.withValues(alpha: 0.7),
      );
    }

    // --- Pusula yıldızı (glyph) ---
    final points = rank <= 2 ? 4 : 8;
    final outerR = r * (rank <= 2 ? 0.34 : 0.44);
    final innerR = outerR * (rank <= 2 ? 0.30 : 0.40);

    // Küçük (ikincil) uçlar soluk, kuzey ucu tam renk.
    final star = _starPath(c, outerR, innerR, points, rotation: -math.pi / 2);
    canvas.drawPath(star, rank >= 3 ? glyphSoft : glyphPaint);

    // Kuzey ucu (yukarı) her rütbede vurgulu — pusula iğnesi hissi.
    final northLen = outerR * (rank == 1 ? 1.0 : 1.25);
    final needle = Path()
      ..moveTo(c.dx - innerR * 0.55, c.dy)
      ..lineTo(c.dx, c.dy - northLen)
      ..lineTo(c.dx + innerR * 0.55, c.dy)
      ..close();
    canvas.drawPath(needle, glyphPaint);

    // Merkez nokta (rütbe 3+)
    if (rank >= 3) {
      canvas.drawCircle(c, innerR * 0.45, glyphPaint);
    }
  }

  Path _hexPath(Offset c, double radius, {bool pointyTop = true}) {
    final path = Path();
    final start = pointyTop ? -math.pi / 2 : 0.0;
    for (var i = 0; i < 6; i++) {
      final a = start + i * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _starPath(Offset c, double outerR, double innerR, int points,
      {double rotation = 0}) {
    final path = Path();
    final step = math.pi / points;
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? outerR : innerR;
      final a = rotation + i * step;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_RankEmblemPainter old) =>
      old.rank != rank || old.color != color;
}
