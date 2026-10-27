// widgets/scrollable_panel.dart — Scrollable dialog/sheet body with an
// always-visible scrollbar so cramped panels make their overflow obvious.

import 'package:flutter/material.dart';

class ScrollablePanel extends StatefulWidget {
  final Widget child;
  final double maxHeightFactor;

  const ScrollablePanel({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.6,
  });

  @override
  State<ScrollablePanel> createState() => _ScrollablePanelState();
}

class _ScrollablePanelState extends State<ScrollablePanel> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * widget.maxHeightFactor,
      ),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.35)),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(4),
        ),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _controller,
            padding: const EdgeInsets.only(right: 14),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
