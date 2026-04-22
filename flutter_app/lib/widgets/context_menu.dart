import 'package:flutter/material.dart';

/// A helper to build a Material context menu that appears at a specific
/// global position (typically the long-press location), matching platform
/// context-menu UX.
class MenuItem {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

Future<void> showContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<MenuItem> items,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      globalPosition,
      globalPosition,
    ),
    Offset.zero & overlay.size,
  );

  await showMenu<int>(
    context: context,
    position: position,
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem<int>(
          value: i,
          child: Row(
            children: [
              Icon(items[i].icon, size: 20, color: items[i].color),
              const SizedBox(width: 12),
              Text(items[i].label, style: TextStyle(color: items[i].color)),
            ],
          ),
        ),
    ],
  ).then((selected) {
    if (selected != null) items[selected].onTap();
  });
}
