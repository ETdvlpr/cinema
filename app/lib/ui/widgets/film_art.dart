import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Generated artwork for a film. The backend has no per-film posters (and downloading them
/// would cost users data), so each title gets its own deterministic gradient and typography.
class FilmArt extends StatelessWidget {
  const FilmArt({
    super.key,
    required this.filmKey,
    required this.title,
    this.subtitle,
    this.showTitle = true,
    this.borderRadius = 20,
    this.titleStyle,
    this.parallax = 0,
    this.imageUrl,
  });

  final String filmKey;
  final String title;
  final String? subtitle;
  final bool showTitle;
  final double borderRadius;
  final TextStyle? titleStyle;

  /// -1..1 as the card slides past the centre of a carousel; layers drift at different speeds.
  final double parallax;

  /// Real artwork (TMDB poster or a thumbnail cut from the cinema's poster). The generated art
  /// stays underneath as the placeholder and as the fallback if it fails to load.
  final String? imageUrl;

  static const _palettes = [
    [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    [Color(0xFF200122), Color(0xFF6F0000), Color(0xFFB33939)],
    [Color(0xFF1A2A6C), Color(0xFF7B2FF7), Color(0xFFFDBB2D)],
    [Color(0xFF141E30), Color(0xFF243B55), Color(0xFF4A6FA5)],
    [Color(0xFF2B1055), Color(0xFF7597DE), Color(0xFFB7E3F5)],
    [Color(0xFF3E1E04), Color(0xFFB0611B), Color(0xFFF4B860)],
    [Color(0xFF0B3D2E), Color(0xFF1E7A5B), Color(0xFF9AD7B8)],
    [Color(0xFF42032C), Color(0xFFD36B00), Color(0xFFF7C873)],
    [Color(0xFF16161D), Color(0xFF4B1D3F), Color(0xFFE85D75)],
  ];

  static int _hash(String s) => s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

  /// The film's accent colour, for use elsewhere (e.g. chips on its page).
  static Color accentFor(String filmKey) => _palettes[_hash(filmKey) % _palettes.length][2];

  @override
  Widget build(BuildContext context) {
    final h = _hash(filmKey);
    final colors = _palettes[h % _palettes.length];
    final angle = (h % 360) / 360 * 3.14159 * 2;
    final initial = title.trim().isEmpty ? '?' : title.trim().characters.first.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment(-1 + (h % 3) * 0.3, -1),
            end: Alignment(1, 1 - (h % 5) * 0.2),
            transform: GradientRotation(angle * 0.15),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final big = box.maxHeight * 0.9;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Soft spotlight
                Positioned(
                  right: -box.maxWidth * 0.3 + parallax * box.maxWidth * 0.35,
                  top: -box.maxHeight * 0.25,
                  child: Container(
                    width: box.maxWidth * 0.95,
                    height: box.maxWidth * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                // Oversized initial as a graphic element
                Positioned(
                  left: -big * 0.08 - parallax * box.maxWidth * 0.2,
                  bottom: -big * 0.28,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: big,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                if (imageUrl != null)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment(parallax * 0.8, -0.4),
                      // Decode at display size: less memory on cheap phones.
                      memCacheWidth: box.maxWidth.isFinite
                          ? (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()
                          : null,
                      filterQuality: FilterQuality.medium,
                      fadeInDuration: const Duration(milliseconds: 300),
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                // Bottom scrim for legibility
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAA000000)],
                      stops: [0.45, 1],
                    ),
                  ),
                ),
                if (showTitle)
                  Padding(
                    padding: EdgeInsets.all(box.maxWidth < 120 ? 10 : 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: (titleStyle ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
                            color: Colors.white,
                            height: 1.05,
                            shadows: const [Shadow(blurRadius: 12, color: Colors.black45)],
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
