import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Motion is decorative: sending an alert never waits for an animation.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.active,
    required this.busy,
    required this.onPressed,
  });
  final bool active;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AppLifecycleListener lifecycle;
  bool pressed = false;
  bool foreground = true;
  bool reduceMotion = false;

  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        foreground = state == AppLifecycleState.resumed;
        updateMotion();
      },
    );
  }

  void updateMotion() {
    if (foreground &&
        !reduceMotion &&
        !widget.busy &&
        TickerMode.valuesOf(context).enabled) {
      if (!pulse.isAnimating) pulse.repeat();
    } else {
      pulse.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    updateMotion();
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy) pressed = false;
    updateMotion();
  }

  @override
  void dispose() {
    lifecycle.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.active
        ? const Color(0xFFF2A23A)
        : const Color(0xFFEF5265);
    final top = widget.active
        ? const Color(0xFFC95B16)
        : const Color(0xFFE63D55);
    final bottom = widget.active
        ? const Color(0xFF872B08)
        : const Color(0xFFA71034);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: !widget.busy,
        label: widget.busy
            ? 'Saving SOS update'
            : widget.active
            ? 'SOS active'
            : 'Send SOS emergency alert',
        hint: widget.active
            ? 'Opens confirmation to end your alert when you are safe'
            : 'Sends an emergency alert immediately',
        onTap: widget.busy ? null : widget.onPressed,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: 264,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SignalRings(
                        pulse: pulse,
                        color: accent,
                        active: widget.active,
                        dark: dark,
                        still: reduceMotion || widget.busy,
                      ),
                    ),
                  ),
                ),
                Listener(
                  onPointerDown: widget.busy
                      ? null
                      : (_) => setState(() => pressed = true),
                  onPointerUp: (_) => setState(() => pressed = false),
                  onPointerCancel: (_) => setState(() => pressed = false),
                  child: AnimatedScale(
                    scale: pressed ? .96 : 1,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: duration,
                      width: 198,
                      height: 198,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [top, bottom],
                          stops: const [.05, 1],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: dark ? .28 : .6,
                          ),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: bottom.withValues(alpha: dark ? .48 : .25),
                            blurRadius: 26,
                            spreadRadius: 1,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: widget.busy ? null : widget.onPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.busy)
                              const SizedBox.square(
                                dimension: 36,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            else
                              Icon(
                                widget.active
                                    ? Icons.sensors_rounded
                                    : Icons.sos,
                                size: widget.active ? 36 : 72,
                              ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.busy
                                    ? 'SAVING…'
                                    : widget.active
                                    ? 'ACTIVE'
                                    : 'TAP FOR HELP',
                                style: TextStyle(
                                  fontSize: widget.active && !widget.busy
                                      ? 28
                                      : 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: widget.active ? 2.5 : 1.6,
                                ),
                              ),
                            ),
                            if (widget.active && !widget.busy) ...[
                              const SizedBox(height: 7),
                              const FittedBox(
                                child: Text(
                                  'SOS IN PROGRESS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.3,
                                    color: Color(0xFFFFE5C5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalRings extends CustomPainter {
  _SignalRings({
    required this.pulse,
    required this.color,
    required this.active,
    required this.dark,
    required this.still,
  }) : super(repaint: pulse);
  final Animation<double> pulse;
  final Color color;
  final bool active;
  final bool dark;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final phase = still ? .25 : pulse.value;
    final breath = (math.sin(phase * math.pi * 2) + 1) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: dark ? .22 : .13),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = 0; i < 2; i++) {
      final wave = (phase + i * .5) % 1;
      canvas.drawCircle(
        center,
        106 + wave * 23,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.8 : 1.2
          ..color = color.withValues(alpha: (1 - wave) * (dark ? .5 : .32)),
      );
    }
    canvas.drawCircle(
      center,
      105,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: .18 + breath * .12),
    );
    // A short travelling arc distinguishes an active alert without flashing.
    if (active) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 117),
        -math.pi / 2 + phase * math.pi * 2,
        math.pi * .38,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = color.withValues(alpha: .8),
      );
    }
  }

  @override
  bool shouldRepaint(_SignalRings old) =>
      old.color != color ||
      old.active != active ||
      old.dark != dark ||
      old.still != still;
}
