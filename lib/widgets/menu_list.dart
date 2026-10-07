import 'package:flutter/material.dart';

/// One row of a [MenuList].
class MenuItem {
  const MenuItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
    this.badge = 0,
  });

  final Key key;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Used for the red "Delete" style row.
  final Color? color;

  /// A number shown on the row when above zero.
  final int badge;
}

/// A rounded card with divided rows. Used by Profile, Settings and Help.
class MenuList extends StatelessWidget {
  const MenuList({super.key, required this.items});

  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              key: items[i].key,
              leading: Icon(items[i].icon, color: items[i].color),
              title: Text(
                items[i].title,
                style: TextStyle(color: items[i].color),
              ),
              subtitle: items[i].subtitle == null
                  ? null
                  : Text(items[i].subtitle!),
              trailing: Badge(
                isLabelVisible: items[i].badge > 0,
                label: Text('${items[i].badge}'),
                child: const Icon(Icons.chevron_right),
              ),
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}
