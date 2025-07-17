import 'package:flutter/material.dart';
import 'package:phil/widgets/background.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showAppBar;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showAppBar = true, // Default to true
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Background(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAppBar) // ✅ Show only if true
                  AppBar(
                    title: Text(title),
                    backgroundColor: Colors.green,
                    automaticallyImplyLeading: true,
                  ),
                if (showAppBar) const SizedBox(height: 20),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
