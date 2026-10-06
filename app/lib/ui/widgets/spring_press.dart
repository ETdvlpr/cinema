import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shrinks under the finger and springs back with a slight overshoot, plus a light haptic tap.
///
/// Uses a real spring simulation (not a fixed-duration tween), so a quick tap and a long press
/// both feel physical. Scrolling cancels the press. Honours the system "reduce motion" setting.
class SpringPress extends StatefulWidget {
  const SpringPress({super.key, required this.child, this.onTap, this.pressedScale = 0.95});

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress> with SingleTickerProviderStateMixin {
  // Underdamped (critical damping here is ~45), so it settles with a small, quick bounce.
  static const _spring = SpringDescription(mass: 1, stiffness: 500, damping: 20);

  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _springTo(double target, {double velocity = 0}) {
    if (_reduceMotion) return;
    _scale.animateWith(SpringSimulation(_spring, _scale.value, target, velocity));
  }

  void _onTapDown(TapDownDetails _) => _springTo(widget.pressedScale);

  void _onTapUp(TapUpDetails _) {
    // A tap shorter than the press animation still gets a visible "dip" from the spring's velocity.
    final barelyPressed = _scale.value > widget.pressedScale + 0.02;
    _springTo(1, velocity: barelyPressed ? -1.2 : _scale.velocity);
  }

  void _onTapCancel() => _springTo(1, velocity: _scale.velocity);

  void _onTap() {
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : _onTapDown,
        onTapUp: widget.onTap == null ? null : _onTapUp,
        onTapCancel: widget.onTap == null ? null : _onTapCancel,
        onTap: widget.onTap == null ? null : _onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
