import 'package:flutter/material.dart';

class AdminDashboardButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget page;

  const AdminDashboardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // shrink to fit
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
