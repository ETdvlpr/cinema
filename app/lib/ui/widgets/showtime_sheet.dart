import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/addis_time.dart';
import '../../data/films.dart';
import '../../data/models.dart';
import '../poster_page.dart';
import '../theme.dart';
import 'film_art.dart';

/// Shows a showtime as a cinema ticket. It rises with a slight overshoot and can be dragged
/// or flung away like any bottom sheet.
Future<void> showShowtimeSheet(BuildContext context, Showtime showtime) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    sheetAnimationStyle: reduceMotion
        ? null
        : const AnimationStyle(
            curve: Curves.easeOutBack,
            duration: Duration(milliseconds: 520),
            reverseCurve: Curves.easeInCubic,
            reverseDuration: Duration(milliseconds: 220),
          ),
    builder: (_) => _TicketSheet(showtime: showtime),
  );
}

class _TicketSheet extends StatelessWidget {
  const _TicketSheet({required this.showtime});

  final Showtime showtime;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = showtime;
    final info = s.info;
    final title = info != null && info.fromTmdb ? info.title : prettyTitle(s.filmTitleLatin);
    final original = s.filmTitle != s.filmTitleLatin ? s.filmTitle : null;
    final accent = FilmArt.accentFor(s.filmKey);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle, floating above the ticket.
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
            ),
            _TicketPart(
              notchAtBottom: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 132,
                    child: FilmArt(
                      filmKey: s.filmKey,
                      title: title,
                      subtitle: original,
                      borderRadius: 0,
                      imageUrl: s.info?.backdrop('w300') ?? s.info?.poster('w342'),
                      titleStyle: text.headlineSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ADMIT ONE',
                              style: text.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.cinema.name.toUpperCase(),
                                style: text.labelSmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Fact(label: 'DATE', value: friendlyDate(s.date)),
                            ),
                            Expanded(
                              child: _Fact(label: 'TIME', value: to12h(s.time), sub: toEthiopianClock(s.time)),
                            ),
                          ],
                        ),
                        if (s.hall != null || s.format != null || s.priceBirr != null || s.language != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.hall != null)
                                Expanded(
                                  child: _Fact(label: 'HALL', value: s.hall!),
                                ),
                              if (s.format != null)
                                Expanded(
                                  child: _Fact(label: 'FORMAT', value: s.format!.toUpperCase()),
                                ),
                              if (s.priceBirr != null)
                                Expanded(
                                  child: _Fact(label: 'PRICE', value: '${s.priceBirr!.toStringAsFixed(0)} ETB'),
                                ),
                              if (s.language != null)
                                Expanded(
                                  child: _Fact(label: 'LANGUAGE', value: s.language!),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _TicketPart(
              notchAtBottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (s.poster != null)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => openPoster(
                                context,
                                imagePath: s.poster!,
                                postUrl: s.postUrl,
                                cinemaName: s.cinema.name,
                              ),
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Source poster'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            ),
                          ),
                        if (s.poster != null) const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => launchUrl(Uri.parse(s.postUrl), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Telegram'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: AppColors.text,
                              side: const BorderSide(color: AppColors.outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Read automatically from the cinema\'s poster. Check the original if it matters.',
                            style: text.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 88,
                          height: 30,
                          child: CustomPaint(painter: _BarcodePainter('${s.filmKey}${s.cinema.id}${s.sortKey}')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(value, style: text.titleMedium),
        if (sub != null) Text(sub!, style: text.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ticket shape: two halves whose facing corners are notched, so together they form
// semicircle cut-outs at the perforation, with a dashed tear line between them.

const _outerRadius = 24.0;
const _notchRadius = 14.0;

class _TicketPart extends StatelessWidget {
  const _TicketPart({required this.notchAtBottom, required this.child});

  final bool notchAtBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _TicketOutlinePainter(notchAtBottom),
      child: ClipPath(
        clipper: _TicketClipper(notchAtBottom),
        child: ColoredBox(color: AppColors.surface, child: child),
      ),
    );
  }
}

Path _ticketPath(Size size, bool notchAtBottom) {
  final w = size.width, h = size.height;
  const r = Radius.circular(_outerRadius), n = Radius.circular(_notchRadius);
  if (notchAtBottom) {
    return Path()
      ..moveTo(0, _outerRadius)
      ..arcToPoint(const Offset(_outerRadius, 0), radius: r)
      ..lineTo(w - _outerRadius, 0)
      ..arcToPoint(Offset(w, _outerRadius), radius: r)
      ..lineTo(w, h - _notchRadius)
      ..arcToPoint(Offset(w - _notchRadius, h), radius: n, clockwise: false)
      ..lineTo(_notchRadius, h)
      ..arcToPoint(Offset(0, h - _notchRadius), radius: n, clockwise: false)
      ..close();
  }
  return Path()
    ..moveTo(0, _notchRadius)
    ..arcToPoint(const Offset(_notchRadius, 0), radius: n, clockwise: false)
    ..lineTo(w - _notchRadius, 0)
    ..arcToPoint(Offset(w, _notchRadius), radius: n, clockwise: false)
    ..lineTo(w, h - _outerRadius)
    ..arcToPoint(Offset(w - _outerRadius, h), radius: r)
    ..lineTo(_outerRadius, h)
    ..arcToPoint(Offset(0, h - _outerRadius), radius: r)
    ..close();
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper(this.notchAtBottom);

  final bool notchAtBottom;

  @override
  Path getClip(Size size) => _ticketPath(size, notchAtBottom);

  @override
  bool shouldReclip(_TicketClipper old) => old.notchAtBottom != notchAtBottom;
}

class _TicketOutlinePainter extends CustomPainter {
  const _TicketOutlinePainter(this.notchAtBottom);

  final bool notchAtBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(_ticketPath(size, notchAtBottom), outline);

    if (!notchAtBottom) {
      // Tear line along the top of the stub.
      final dash = Paint()
        ..color = AppColors.textMuted.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (var x = _notchRadius + 10; x < size.width - _notchRadius - 10; x += 10) {
        canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_TicketOutlinePainter old) => old.notchAtBottom != notchAtBottom;
}

/// Decorative barcode, unique per showing. Not scannable; it's a nod to a real ticket.
class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.seed);

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.text.withValues(alpha: 0.75);
    var h = seed.codeUnits.fold(17, (a, c) => (a * 31 + c) & 0x7fffffff);
    var x = 0.0;
    while (x < size.width) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final bar = 1.0 + (h % 3);
      final gap = 1.0 + ((h >> 4) % 2) * 1.5;
      canvas.drawRect(Rect.fromLTWH(x, 0, bar, size.height), paint);
      x += bar + gap;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.seed != seed;
}
