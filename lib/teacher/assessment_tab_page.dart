import 'package:flutter/material.dart';
import 'package:phil/teacher/assessment_page.dart';
import 'package:phil/teacher/assessment_quizzes.dart';
import 'package:phil/widgets/background.dart';

class AssessmentTabPage extends StatefulWidget {
  final String teacherId;

  const AssessmentTabPage({super.key, required this.teacherId});

  @override
  State<AssessmentTabPage> createState() => _AssessmentTabPageState();
}

class _AssessmentTabPageState extends State<AssessmentTabPage> {
  int _selectedIndex = 0; // 0 = Passages, 1 = Quizzes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Background(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF15A323),
            elevation: 0,
            centerTitle: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 0),
                    child: Text(
                      'Passages',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: _selectedIndex == 0
                            ? Colors.yellow
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white,
                ),
                Flexible(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 1),
                    child: Text(
                      'Quizzes',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: _selectedIndex == 1
                            ? Colors.yellow
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: _selectedIndex == 0
              ? AssessmentPage(teacherId: widget.teacherId)
              : AssessmentQuizzesPage(teacherId: widget.teacherId),
        ),
      ),
    );
  }
}
