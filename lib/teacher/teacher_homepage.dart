import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:phil/main.dart';
import 'package:phil/teacher/student_list_page.dart';
import 'package:phil/widgets/reading_profile_dynamic_table.dart';
import 'teacher_drawer.dart';
import 'package:phil/widgets/gender_pie_chart.dart';
import 'package:phil/widgets/grade_bar_chart.dart';
import "package:phil/teacher/assessment_tab_page.dart";
import "package:phil/widgets/miscue_bar_chart.dart";

class TeacherHomePage extends StatefulWidget {
  final String teacherId;

  const TeacherHomePage({super.key, required this.teacherId});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  String firstName = '';
  String lastName = '';
  String teacherCode = '';
  int studentCount = 0;
  int _currentIndex = 1; // Default index set to 'Home'
  DateTime? _lastBackPressed; // Used for double-back-to-logout

  @override
  void initState() {
    super.initState();
    _verifyTeacherId();
  }

  Future<void> _verifyTeacherId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("Error: User is not authenticated.");
      return;
    }
    if (currentUser.uid != widget.teacherId) {
      debugPrint(
        "Error: Authenticated user UID (${currentUser.uid}) does not match teacherId (${widget.teacherId})",
      );
      return;
    }
    _fetchTeacherData();
    _fetchStudentCount();
  }

  Future<void> _fetchTeacherData() async {
    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('Teachers')
          .doc(widget.teacherId)
          .get();

      if (teacherDoc.exists) {
        final data = teacherDoc.data() as Map<String, dynamic>;
        setState(() {
          firstName = data['firstname'] ?? 'Unknown';
          lastName = data['lastname'] ?? '';
          teacherCode = data['teacherCode'] ?? 'No code available';
        });
      }
    } catch (e) {
      debugPrint('Error fetching teacher data: $e');
    }
  }

  Future<void> _fetchStudentCount() async {
    try {
      final studentsQuery = await FirebaseFirestore.instance
          .collection('Students')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      setState(() {
        studentCount = studentsQuery.docs.length;
      });
    } catch (e) {
      debugPrint('Error fetching student count: $e');
    }
  }

  // Double-back shows confirmation dialog before logout (HCI)
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
    }

    return false; // Default return statement to ensure a non-nullable bool is returned.
  }

  Widget _buildHomePage() {
    final today = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    return Stack(
      children: [
        // Background Image
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Main Content
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Logo
              SizedBox(
                width: 320,
                height: 320,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              // Welcome Message
              Text(
                "Hello Teacher $firstName $lastName",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Current Date
              Text(
                "Today is $today.",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Student Count
              Text(
                "You currently have $studentCount student(s) enrolled in your class.",
                style: const TextStyle(fontSize: 18, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Class Code
              Text(
                "Class Code: $teacherCode",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 70),

              // Gender Pie Chart
              GenderPieChart(teacherId: FirebaseAuth.instance.currentUser!.uid),
              const SizedBox(height: 70),

              // Grade Bar Chart
              GradeBarChart(
                isTeacher: true,
                teacherId: FirebaseAuth.instance.currentUser!.uid,
              ),

              // Miscue Bar Chart
              MiscueBarChart(teacherId: FirebaseAuth.instance.currentUser!.uid),

              // Reading Profile Tables
              ReadingProfileGlassTable(
                teacherId: widget.teacherId,
                type: "pretest",
              ),
              const SizedBox(height: 32),
              ReadingProfileGlassTable(
                teacherId: widget.teacherId,
                type: "posttest",
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AssessmentTabPage(teacherId: widget.teacherId),
      _buildHomePage(),
      StudentListPage(teacherId: widget.teacherId),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: _currentIndex == 1
            ? AppBar(
                backgroundColor: const Color(0xFF15A323),
                title: const Text(
                  'Teacher Home',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              )
            : null, // Only display AppBar on Home tab
        drawer: _currentIndex == 1
            ? TeacherDrawer(teacherId: widget.teacherId)
            : null,
        body: pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assessment),
              label: 'Assessments',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Students'),
          ],
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
