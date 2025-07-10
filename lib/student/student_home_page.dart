import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_drawer.dart';
import '../constant.dart';
import 'student_assessment.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'package:reading_comprehension/main.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key, required String studentId});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  String firstName = '';
  String lastName = '';
  String teacherName = '';
  String teacherProfileUrl = '';
  bool isLoading = true;
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _fetchStudentInfo();
  }

  Future<void> _fetchStudentInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final studentDoc = await FirebaseFirestore.instance.collection('Students').doc(user.uid).get();
    if (studentDoc.exists) {
      final studentData = studentDoc.data()!;
      final teacherId = studentData['teacherId'];

      setState(() {
        firstName = studentData['firstName'];
        lastName = studentData['lastName'];
      });

      if (teacherId != null && teacherId.isNotEmpty) {
        final teacherDoc = await FirebaseFirestore.instance.collection('Teachers').doc(teacherId).get();
        if (teacherDoc.exists) {
          setState(() {
            teacherName = '${teacherDoc['firstname']} ${teacherDoc['lastname']}';
            teacherProfileUrl = teacherDoc.data()?.containsKey('profilePictureUrl') == true
                ? teacherDoc['profilePictureUrl']
                : '';
          });
        }
      }
    }

    setState(() => isLoading = false);
  }

  Future<bool> _onWillPop() async {
    DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      setState(() {
        _lastBackPressed = now;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Press BACK again to log out."),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }

    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Do you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return false;
      Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MyHomePage()),
      (route) => false,
);

      return false;
    } else {
      return false;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeContent(String studentId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          SizedBox(
            width: 320,
            height: 320,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 10),

          // Greeting
          Text(
            "Hi, $firstName $lastName!",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          // Teacher Info (Readable & Branded)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FBEF),
              border: Border.all(color: const Color(0xFF15A323), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF15A323), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    child: ClipOval(
                      child: teacherProfileUrl.trim().isNotEmpty
                          ? Image.network(
                              teacherProfileUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/default_profile.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/default_profile.png',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Teacher",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacherName.isNotEmpty ? teacherName : "Not Assigned",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final studentId = user?.uid ?? '';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Background(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _selectedIndex == 0
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                )
              : null,
          drawer: StudentDrawer(studentId: studentId),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildHomeContent(studentId), // Home
                    StudentAssessment(studentId: studentId), // Assessment
                  ],
                ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: 'Assessment',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
