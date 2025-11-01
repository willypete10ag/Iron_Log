import 'package:flutter/material.dart';

/// Lightweight custom toast/snackbar overlay for IronLog.
/// Shows for ~2 seconds at the bottom of the screen.
/// Supports an optional [leading] icon widget and adapts to the current theme.
void showIronToast(
  BuildContext context,
  String message, {
  Widget? leading,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context);

  final overlayEntry = OverlayEntry(
    builder: (context) => _IronToastWidget(
      message: message,
      leading: leading,
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(duration, () {
    overlayEntry.remove();
  });
}

class _IronToastWidget extends StatelessWidget {
  final String message;
  final Widget? leading;

  const _IronToastWidget({
    required this.message,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Position just above bottom nav bar + safe area
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        60; // slightly higher for nav visibility

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding,
      child: Material(
        color: Colors.transparent,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.primary.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      size: 20,
                      color: cs.primary,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    message,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
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
