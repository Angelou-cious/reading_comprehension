import 'package:flutter/material.dart';
import 'package:reading_comprehension/student/student_sign_up.dart';
import 'package:reading_comprehension/teacher/teacher_sign_up.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool _maintenanceMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkMaintenance();
  }

  Future<void> _checkMaintenance() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('AppSettings')
          .doc('global')
          .get();
      setState(() {
        _maintenanceMode = doc.data()?['maintenanceMode'] ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Maintenance Mode"),
        content: const Text(
          "Sign up is currently disabled due to system maintenance.\nPlease try again later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Background(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    SizedBox(
                      height: 300,
                      width: 400,
                      child: Image.asset(
                        "assets/images/logo.png",
                        fit: BoxFit.fill,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome Onboard!",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Sign Up to Get Started",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildButton(
                      context,
                      "Sign Up as a Teacher",
                      const SignUpTeacher(),
                      const Color(0xFF15A323),
                      enabled: !_maintenanceMode,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "OR",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildButton(
                      context,
                      "Sign Up as a Student",
                      const SignUpStudent(),
                      const Color(0xFF15A323),
                      enabled: !_maintenanceMode,
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Sign In!",
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_maintenanceMode) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange, width: 1.2),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Maintenance Mode is enabled. Sign up is temporarily disabled for all users.",
                                style: TextStyle(fontSize: 15, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, String text, Widget destination, Color color,
      {bool enabled = true}) {
    return Container(
      width: 300,
      height: 50,
      decoration: BoxDecoration(
        color: enabled ? color : Colors.grey,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextButton(
        onPressed: enabled
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => destination),
                );
              }
            : _showMaintenanceDialog,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
