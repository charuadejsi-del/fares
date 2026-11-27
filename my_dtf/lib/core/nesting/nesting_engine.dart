/// My DTF — moteur d'imbrication (estimation du métrage).
///
/// Range les images du client sur une laize fixe (58 cm par défaut) avec un
/// espacement entre images (0,3 cm) et rotation 90° autorisée, en minimisant
/// la longueur de film consommée. Algorithme : « skyline bottom-left »,
/// essayé avec plusieurs ordres de tri ; on garde le meilleur résultat.
///
/// Code Dart pur (aucune dépendance Flutter) : utilisable dans l'app client,
/// le site et le logiciel PC.
library;

import 'dart:math' as math;

/// Une image demandée par le client.
class NestItem {
  final String id;
  final double widthCm;
  final double heightCm;
  final int quantity;

  const NestItem({
    required this.id,
    required this.widthCm,
    required this.heightCm,
    required this.quantity,
  });
}

/// Position d'une copie d'image sur le film (coin haut-gauche, en cm).
class Placement {
  final String itemId;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool rotated;

  const Placement(
      this.itemId, this.x, this.y, this.width, this.height, this.rotated);
}

class NestResult {
  /// Longueur de film utilisée, en cm (sans espacement après la dernière ligne).
  final double lengthCm;
  final double filmWidthCm;
  final List<Placement> placements;

  const NestResult(this.lengthCm, this.filmWidthCm, this.placements);

  double get lengthM => lengthCm / 100;

  /// Taux de remplissage du film (0..1), utile pour l'aperçu.
  double get fillRatio {
    if (lengthCm <= 0) return 0;
    final used = placements.fold<double>(0, (s, p) => s + p.width * p.height);
    return used / (lengthCm * filmWidthCm);
  }
}

/// Erreur : une image ne rentre pas dans la laize, même tournée.
class ItemTooWideException implements Exception {
  final String itemId;
  ItemTooWideException(this.itemId);
  @override
  String toString() => 'Image $itemId plus large que le film';
}

class NestingEngine {
  final double filmWidthCm;
  final double gapCm;
  final bool allowRotation;

  const NestingEngine({
    this.filmWidthCm = 58,
    this.gapCm = 0.3,
    this.allowRotation = true,
  });

  NestResult nest(List<NestItem> items) {
    final copies = <_Copy>[];
    for (final it in items) {
      if (it.widthCm <= 0 || it.heightCm <= 0 || it.quantity <= 0) continue;
      final fits = it.widthCm <= filmWidthCm ||
          (allowRotation && it.heightCm <= filmWidthCm);
      if (!fits) throw ItemTooWideException(it.id);
      // Trop large à plat : on la pose tournée d'office.
      final turn = it.widthCm > filmWidthCm;
      for (var i = 0; i < it.quantity; i++) {
        copies.add(turn
            ? _Copy(it.id, it.heightCm, it.widthCm, true)
            : _Copy(it.id, it.widthCm, it.heightCm));
      }
    }
    if (copies.isEmpty) return NestResult(0, filmWidthCm, const []);

    final orders = <int Function(_Copy, _Copy)>[
      (a, b) => b.h.compareTo(a.h),
      (a, b) => b.w.compareTo(a.w),
      (a, b) => (b.w * b.h).compareTo(a.w * a.h),
      (a, b) => math.max(b.w, b.h).compareTo(math.max(a.w, a.h)),
    ];

    // Le choix de rotation copie par copie (glouton) peut piéger : ex. 28,5×30
    // tourné empêche de mettre 2 images côte à côte. On essaie donc aussi des
    // orientations fixées à l'avance (sans rotation, tout en paysage, tout en
    // portrait) et on garde le film le plus court.
    _Copy orient(_Copy c, bool landscape) {
      final shouldTurn = landscape ? c.w < c.h : c.w > c.h;
      if (shouldTurn && c.h <= filmWidthCm) {
        return _Copy(c.id, c.h, c.w, true);
      }
      return c;
    }

    final variants = <(List<_Copy>, bool)>[
      (copies, false),
      if (allowRotation) ...[
        (copies, true),
        ([for (final c in copies) orient(c, true)], false),
        ([for (final c in copies) orient(c, false)], false),
      ],
    ];

    NestResult? best;
    for (final (cs, greedy) in variants) {
      for (final cmp in orders) {
        final sorted = [...cs]..sort(cmp);
        final r = _skyline(sorted, greedy);
        if (best == null || r.lengthCm < best.lengthCm - 1e-9) best = r;
      }
    }
    return best!;
  }

  NestResult _skyline(List<_Copy> copies, bool greedyRotation) {
    // On réserve « gap » à droite et en bas de chaque image ;
    // la laize virtuelle vaut donc filmWidth + gap.
    final binW = filmWidthCm + gapCm;
    var sky = <_Seg>[_Seg(0, 0, binW)];
    final out = <Placement>[];

    for (final c in copies) {
      final options = <List<dynamic>>[
        [c.w, c.h, c.rotated],
        if (greedyRotation && (c.w - c.h).abs() > 1e-9) [c.h, c.w, !c.rotated],
      ];
      _Fit? bestFit;
      for (final o in options) {
        final w = (o[0] as double) + gapCm;
        final h = (o[1] as double) + gapCm;
        if (w > binW + 1e-9) continue;
        for (var i = 0; i < sky.length; i++) {
          final x = sky[i].x;
          if (x + w > binW + 1e-9) break;
          // hauteur du skyline sous [x, x+w]
          var y = 0.0;
          var rem = w;
          for (var j = i; j < sky.length && rem > 1e-9; j++) {
            y = math.max(y, sky[j].y);
            rem -= sky[j].w;
          }
          final top = y + h;
          final f = _Fit(x, y, w, h, o[2] as bool, top);
          if (bestFit == null ||
              top < bestFit.top - 1e-9 ||
              ((top - bestFit.top).abs() <= 1e-9 &&
                  (y < bestFit.y - 1e-9 ||
                      ((y - bestFit.y).abs() <= 1e-9 && x < bestFit.x)))) {
            bestFit = f;
          }
        }
      }
      final f = bestFit!;
      out.add(Placement(
          c.id, f.x, f.y, f.w - gapCm, f.h - gapCm, f.rotated));
      sky = _addToSkyline(sky, f.x, f.w, f.top);
    }

    final length = out.fold<double>(0, (m, p) => math.max(m, p.y + p.height));
    return NestResult(_round(length), filmWidthCm, out);
  }

  List<_Seg> _addToSkyline(List<_Seg> sky, double x, double w, double top) {
    final res = <_Seg>[];
    final end = x + w;
    for (final s in sky) {
      final sEnd = s.x + s.w;
      if (sEnd <= x + 1e-9 || s.x >= end - 1e-9) {
        res.add(s);
        continue;
      }
      if (s.x < x) res.add(_Seg(s.x, s.y, x - s.x));
      if (sEnd > end) res.add(_Seg(end, s.y, sEnd - end));
    }
    res.add(_Seg(x, top, w));
    res.sort((a, b) => a.x.compareTo(b.x));
    // fusion des segments contigus de même hauteur
    final merged = <_Seg>[];
    for (final s in res) {
      if (merged.isNotEmpty && (merged.last.y - s.y).abs() < 1e-9) {
        final l = merged.removeLast();
        merged.add(_Seg(l.x, l.y, l.w + s.w));
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}

class _Copy {
  final String id;
  final double w;
  final double h;
  final bool rotated;
  _Copy(this.id, this.w, this.h, [this.rotated = false]);
}

class _Seg {
  final double x;
  final double y;
  final double w;
  _Seg(this.x, this.y, this.w);
}

class _Fit {
  final double x, y, w, h, top;
  final bool rotated;
  _Fit(this.x, this.y, this.w, this.h, this.rotated, this.top);
}
