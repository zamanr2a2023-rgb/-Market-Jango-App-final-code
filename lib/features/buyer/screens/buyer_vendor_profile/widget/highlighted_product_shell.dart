import 'package:flutter/material.dart';

Map<String, dynamic> buyerVendorProfileExtra({
  required int vendorId,
  required int userId,
  int? highlightProductId,
}) {
  return {
    'vendorId': vendorId,
    'userId': userId,
    if (highlightProductId != null && highlightProductId > 0)
      'highlightProductId': highlightProductId,
  };
}

/// Light entrance animation for the selected product card.
class HighlightedProductShell extends StatefulWidget {
  const HighlightedProductShell({
    super.key,
    required this.isHighlighted,
    required this.child,
  });

  final bool isHighlighted;
  final Widget child;

  @override
  State<HighlightedProductShell> createState() =>
      _HighlightedProductShellState();
}

class _HighlightedProductShellState extends State<HighlightedProductShell>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );
      _scale = Tween<double>(begin: 0.97, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
      );
      _controller!.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHighlighted || _scale == null) return widget.child;

    return AnimatedBuilder(
      animation: _scale!,
      builder: (context, child) => Transform.scale(
        scale: _scale!.value,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: widget.child,
    );
  }
}
