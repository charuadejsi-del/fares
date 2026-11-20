// إطار الصورة الرمزية حسب لقب الأسبوع الماضي (أسطورة، نخبة، أفضل 100).
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/social.dart';
import 'ui_kit.dart';

class TitleAvatar extends StatelessWidget {
  final String name;
  final String? title;
  final double size;
  const TitleAvatar(this.name, {super.key, this.title, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final t = title == null ? null : kTitles[title];
    if (t == null) return Avatar(name, size: size);
    final c = Color(t.$2);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(K.radius + 2),
        border: Border.all(color: c, width: 1.5),
      ),
      child: Avatar(name, size: size - 6),
    );
  }
}

class TitleBadge extends StatelessWidget {
  final String? title;
  const TitleBadge(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = title == null ? null : kTitles[title];
    if (t == null) return const SizedBox.shrink();
    final c = Color(t.$2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withAlpha(150))),
      child: Text(t.$1, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

/// وقت متبقٍّ مقروء.
String leftText(DateTime end) {
  final d = end.difference(DateTime.now());
  if (d.isNegative) return 'ينتهي الآن';
  if (d.inDays > 0) return '${d.inDays} يوم ${d.inHours % 24} سا';
  return '${d.inHours} سا ${d.inMinutes % 60} د';
}

const TextStyle kSeasonNote = TextStyle(color: K.muted, fontSize: 12);
