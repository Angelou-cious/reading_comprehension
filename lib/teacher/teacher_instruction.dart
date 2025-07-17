import 'package:flutter/material.dart';
import 'package:phil/widgets/background_reading.dart';

class TeacherInstructionPage extends StatelessWidget {
  const TeacherInstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Background(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Teacher Instructions'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'CISCKIDS: Mobile Reading Comprehension',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),

              Text(
                'Getting Started with the App',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Divider(),
              SizedBox(height: 10),
              Text(
                '• Home Page: Provides an overview of your teaching dashboard, including total student count and quick links to important tools such as assessments and charts. It is your starting point for managing students and content efficiently.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Assessment Page: Allows you to create and manage reading passages and quizzes. You can specify the set, grade level, and type (Pretest, Posttest, or Custom). Once created, these assessments can be assigned to students.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Assign Feature: After creating content, navigate to the Assign section to assign a specific story and quiz pair to selected students. You can filter by grade level, view student names, and assign materials in bulk.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Student List: Displays all students registered under your teacher code. You can view student details, check assignment status, and mark oral reading miscues after assessments. Each student profile includes performance history.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Performance Charts: Visualize student progress through gender breakdowns and reading profile distributions for Grades 5 and 6. These insights help track improvement over time and identify students needing support.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Navigation Drawer: Use the sidebar menu to move between key sections such as Home, Assessments, Charts, Student List, Instructions, and Logout. This ensures efficient navigation within the app.',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 30),
              Text(
                'Understanding Reading Profiles (Based on Phil-IRI Standards)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Divider(),
              SizedBox(height: 10),
              Text(
                'A student\'s reading level is assessed based on two factors: oral reading accuracy and comprehension score. These are derived after a student reads a passage aloud and answers questions from the related quiz.',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 20),
              Text(
                'Independent Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '• Word Recognition Accuracy: 97% to 100%',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '• Comprehension Score: 80% to 100%',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),

              Text(
                'Instructional Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '• Word Recognition Accuracy: 90% to 96%',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '• Comprehension Score: 59% to 79%',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),

              Text(
                'Frustration Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '• Word Recognition Accuracy: Below 90%',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '• Comprehension Score: Below 59%',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 25),
              Text(
                'Calculating Word Recognition',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Formula: (Total Words Read - Total Miscues) ÷ Total Words Read × 100',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Example: If a student read 120 words and committed 6 miscues, the calculation is:\n(120 - 6) ÷ 120 × 100 = 95%.',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 20),
              Text(
                'Calculating Comprehension',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Formula: Number of Correct Answers ÷ Total Questions × 100',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Example: If a student answered 7 out of 10 questions correctly:\n7 ÷ 10 × 100 = 70%',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 30),
              Text(
                'Final Teaching Tips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Use the generated data to guide your instruction. Focus on students who fall in the instructional and frustration levels, and provide targeted reading exercises. Monitor growth through consistent assessments and adjust the difficulty of assigned materials accordingly.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              Center(
                child: Text(
                  'Thank you for supporting your students\' literacy journey.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
