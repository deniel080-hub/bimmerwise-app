import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Safe Lottie widget that delays loading until after first frame
/// and provides fallback icons on error - prevents iOS startup crashes
class SafeLottie extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool repeat;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const SafeLottie({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit,
    this.repeat = true,
    this.fallbackIcon = Icons.animation,
    this.fallbackColor,
  });

  @override
  State<SafeLottie> createState() => _SafeLottieState();
}

class _SafeLottieState extends State<SafeLottie> {
  bool _shouldLoad = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Delay loading until after first frame to prevent iOS startup crash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _shouldLoad = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder icon until Lottie is ready to load
    if (!_shouldLoad || _hasError) {
      return Icon(
        widget.fallbackIcon,
        size: widget.width ?? widget.height ?? 24,
        color: widget.fallbackColor ?? Theme.of(context).iconTheme.color,
      );
    }

    try {
      return Lottie.asset(
        widget.assetPath,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        repeat: widget.repeat,
        errorBuilder: (context, error, stackTrace) {
          // Show fallback icon on error
          if (mounted) {
            setState(() => _hasError = true);
          }
          return Icon(
            widget.fallbackIcon,
            size: widget.width ?? widget.height ?? 24,
            color: widget.fallbackColor ?? Theme.of(context).iconTheme.color,
          );
        },
      );
    } catch (e) {
      // Catch any synchronous errors
      return Icon(
        widget.fallbackIcon,
        size: widget.width ?? widget.height ?? 24,
        color: widget.fallbackColor ?? Theme.of(context).iconTheme.color,
      );
    }
  }
}
