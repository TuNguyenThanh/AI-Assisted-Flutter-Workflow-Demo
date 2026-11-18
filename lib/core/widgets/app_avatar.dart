import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Circular avatar: network image with an initials fallback that is also
/// shown while loading and when the URL is broken.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = AppSize.avatarLg,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Semantics(
      image: true,
      label: '$name avatar',
      child: CircleAvatar(
        radius: size / 2,
        foregroundImage: url != null ? NetworkImage(url) : null,
        onForegroundImageError: url != null ? (_, _) {} : null,
        child: ExcludeSemantics(child: Text(_initials)),
      ),
    );
  }
}
