import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constant.dart';
import 'story_detail_and_quiz_page.dart';
import 'package:phil/widgets/background.dart';

class StudentAssessment extends StatefulWidget {
  final String studentId;

  const StudentAssessment({super.key, required this.studentId});

  @override
  State<StudentAssessment> createState() => _StudentAssessmentState();
}

class _StudentAssessmentState extends State<StudentAssessment> {
  bool _isProcessing = false;
  List<DocumentSnapshot> assignedItems = [];
  bool isLoading = true;
  Map<String, Map<String, dynamic>> quizDetails = {};
  bool pretestCompleted = false;
  bool postTestDone = false;

  @override
  void initState() {
    super.initState();
    loadAssignedItems();
  }

  Future<void> loadAssignedItems() async {
    try {
      final firestore = FirebaseFirestore.instance;

      final schoolYearSnapshot = await firestore
          .collection('Settings')
          .doc('SchoolYear')
          .get();
      final currentSchoolYear = schoolYearSnapshot.data()?['active'] ?? '';

      final assignedAssessmentsSnapshot = await firestore
          .collection('Students')
          .doc(widget.studentId)
          .collection('AssignedAssessments')
          .where('schoolYear', isEqualTo: currentSchoolYear)
          .get();

      final assignedQuizzesSnapshot = await firestore
          .collection('AssignedQuizzes')
          .where('studentId', isEqualTo: widget.studentId)
          .where('schoolYear', isEqualTo: currentSchoolYear)
          .get();

      final studentSnapshot = await firestore
          .collection('Students')
          .doc(widget.studentId)
          .get();

      bool pretestDone = false;
      // bool postTestDone = false;

      if (studentSnapshot.exists) {
        pretestDone = studentSnapshot.data()?['pretestCompleted'] ?? false;
      }

      final performanceSnapshot = await firestore
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: widget.studentId)
          .where('schoolYear', isEqualTo: currentSchoolYear)
          .get();

      Map<String, Map<String, dynamic>> details = {};
      for (var doc in performanceSnapshot.docs) {
        var data = doc.data();
        var totalScore = data['totalScore'] ?? 0;
        var totalQuestions = data['totalQuestions'] ?? 1;
        var type = data['type'] ?? "Unknown";
        var quizId = doc['quizId'];

        details[quizId] = {
          "score": "$totalScore/$totalQuestions",
          "type": type,
        };

        if (type.toLowerCase() == "post test" && totalScore > 0) {
          postTestDone = true;
        }
      }

      setState(() {
        assignedItems = [
          ...assignedAssessmentsSnapshot.docs,
          ...assignedQuizzesSnapshot.docs,
        ];
        quizDetails = details;
        pretestCompleted = pretestDone;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching assigned items: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> createOrUpdateStudentPerformanceRecord(
    String studentId,
    String storyId,
    String quizId,
    String type,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final schoolYearSnapshot = await firestore
          .collection('Settings')
          .doc('SchoolYear')
          .get();
      final currentSchoolYear = schoolYearSnapshot.data()?['active'] ?? '';

      final existingRecord = await firestore
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: studentId)
          .where('quizId', isEqualTo: quizId)
          .where('schoolYear', isEqualTo: currentSchoolYear)
          .limit(1)
          .get();

      if (existingRecord.docs.isNotEmpty) {
        return existingRecord.docs.first.id;
      }

      final newPerformanceRef = await firestore
          .collection('StudentPerformance')
          .add({
            'studentId': studentId,
            'storyId': storyId,
            'quizId': quizId,
            'startTime': Timestamp.now(),
            'type': type,
            'doneReading': false,
            'miscueMarks': {},
            'totalScore': 0,
            'totalQuestions': 0,
            'schoolYear': currentSchoolYear, // ✅ Added field
          });

      return newPerformanceRef.id;
    } catch (e) {
      print("❌ Error creating/updating StudentPerformance record: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Loading...',
            style: TextStyle(color: neutralColor),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.green,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'ASSIGNED PASSAGES',
          style: TextStyle(color: neutralColor),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
        leading: null,
      ),
      body: Stack(
        children: [
          Background(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 20.0),
                    itemCount: assignedItems.length,
                    itemBuilder: (context, index) {
                      var item = assignedItems[index];
                      var storyId = item['storyId'];
                      var quizId = item['quizId'];
                      var type = item['type'] ?? "Unknown";

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('Stories')
                            .doc(storyId)
                            .get(),
                        builder: (context, storySnapshot) {
                          if (storySnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else if (storySnapshot.hasError) {
                            return Center(
                              child: Text('Error: ${storySnapshot.error}'),
                            );
                          } else if (!storySnapshot.hasData ||
                              !storySnapshot.data!.exists) {
                            return const Center(child: Text('Story not found'));
                          }

                          var storyData = storySnapshot.data;
                          var storyTitle = storyData?['title'] ?? 'No Title';
                          var isCompleted = quizDetails.containsKey(quizId);
                          var quizDetail = quizDetails[quizId] ?? {};
                          var score = quizDetail['score'] ?? '0/0';
                          bool isPostTestLocked =
                              (type == "Post test" && !pretestCompleted);

                          return Card(
                            color: isCompleted ? Colors.amber : Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 10.0,
                              horizontal: 20.0,
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      storyTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isCompleted)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Type: $type",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isCompleted)
                                    Text(
                                      "Score: $score",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed:
                                    (isPostTestLocked ||
                                        isCompleted ||
                                        _isProcessing)
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              "Start Assessment",
                                            ),
                                            content: const Text(
                                              "Are you sure you want to start this assessment now?",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: const Text(
                                                  "Cancel",
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: const Text(
                                                  "Yes, Proceed",
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm != true) return;

                                        setState(() => _isProcessing = true);

                                        final performanceId =
                                            await createOrUpdateStudentPerformanceRecord(
                                              widget.studentId,
                                              storyId,
                                              quizId,
                                              type,
                                            );

                                        if (performanceId != null) {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StoryDetailAndQuizPage(
                                                    storyId: storyId,
                                                    quizId: quizId,
                                                    startTime: DateTime.now(),
                                                    studentId: widget.studentId,
                                                    performanceId:
                                                        performanceId,
                                                  ),
                                            ),
                                          );
                                        }

                                        setState(() => _isProcessing = false);
                                      },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  backgroundColor:
                                      (isPostTestLocked || isCompleted)
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                                child: Text(
                                  isPostTestLocked
                                      ? 'Posttest Locked'
                                      : isCompleted
                                      ? 'Completed'
                                      : 'Read & Quiz',
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
