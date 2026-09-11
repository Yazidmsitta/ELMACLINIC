import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Two columns with equal card height per row, including enlarged text.
class ElmaEqualRows extends StatelessWidget {
  const ElmaEqualRows({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (int i = 0; i < children.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : ElmaSpace.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: ElmaSpace.md),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
