import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phil/main.dart';
import 'package:phil/teacher/teacher_homepage.dart';
import 'package:phil/student/student_home_page.dart';

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  _AuthenticationWrapperState createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        return AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CAF50).withOpacity(_fadeAnimation.value),
                    const Color(0xFFFFEB3B).withOpacity(_fadeAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: child,
            );
          },
          child: _buildContent(authSnapshot),
        );
      },
    );
  }

  Widget _buildContent(AsyncSnapshot<User?> authSnapshot) {
    if (authSnapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox.expand(); // Splash handles loading
    }

    if (!authSnapshot.hasData || authSnapshot.data == null) {
      return const MyHomePage(); // Not logged in
    }

    final User user = authSnapshot.data!;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Teachers')
          .doc(user.uid)
          .get(),
      builder: (context, teacherSnapshot) {
        if (teacherSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.expand();
        }

        if (teacherSnapshot.hasData && teacherSnapshot.data!.exists) {
          return TeacherHomePage(teacherId: user.uid); // ✅ Found in Teachers
        }

        // ➕ Now check Students if not found in Teachers
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('Students')
              .doc(user.uid)
              .get(),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.expand();
            }

            if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
              return StudentHomePage(
                studentId: user.uid,
              ); // ✅ Found in Students
            }

            return const MyHomePage(); // ❌ Not found in either
          },
        );
      },
    );
  }
}
