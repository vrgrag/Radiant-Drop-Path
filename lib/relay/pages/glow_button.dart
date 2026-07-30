import 'package:flutter/material.dart';

/// Shared button for the relay screens. Sized generously and centred without
/// safe-area padding in landscape — the notch inset otherwise shifts the
/// horizontal centre and the button reads as skewed against the artwork.
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.secondary = false,
  });

  final String label;
  final double width;
  final double height;
  final double fontSize;
  final VoidCallback onTap;
  final IconData? icon;
  final bool busy;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    final gradient = secondary
        ? const <Color>[Color(0xFF3B2E63), Color(0xFF251C42)]
        : const <Color>[Color(0xFF35E9FF), Color(0xFFB55CFF)];
    final foreground = secondary
        ? const Color(0xFFDCE6FF)
        : const Color(0xFF0A0E1A);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: secondary
                ? const Color(0xFF6E7CB8)
                : const Color(0xFFEAF6FF),
            width: 2.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (secondary ? const Color(0xFF6E7CB8) : Colors.cyanAccent)
                  .withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: height * 0.4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: foreground,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, color: foreground, size: fontSize * 1.2),
                          SizedBox(width: fontSize * 0.4),
                        ],
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
