import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constant.dart';
import 'story_detail_and_quiz_page.dart';
import 'package:reading_comprehension/widgets/background.dart';

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
  Map<String, Map<String, dynamic>> quizDetails = {}; // Map to store quiz scores and types
  bool pretestCompleted = false; // Tracks if pretest is completed

  @override
  void initState() {
    super.initState();
    loadAssignedItems();
  }

  Future<void> loadAssignedItems() async {
    try {
      var assignedAssessmentsSnapshot = await FirebaseFirestore.instance
          .collection('Students')
          .doc(widget.studentId)
          .collection('AssignedAssessments')
          .get();

      var assignedQuizzesSnapshot = await FirebaseFirestore.instance
          .collection('AssignedQuizzes')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      var studentSnapshot = await FirebaseFirestore.instance
          .collection('Students')
          .doc(widget.studentId)
          .get();

      bool pretestDone = false;
      bool posttestDone = false;

      if (studentSnapshot.exists) {
        pretestDone = studentSnapshot.data()?['pretestCompleted'] ?? false;
      }

      var performanceSnapshot = await FirebaseFirestore.instance
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: widget.studentId)
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
          posttestDone = true;
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

      debugPrint('✅ Pretest Completed: $pretestCompleted, Posttest Completed: $posttestDone');
    } catch (e) {
      print("❌ Error fetching assigned items: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  /// ✅ **Correct Placement of `createOrUpdateStudentPerformanceRecord`**
Future<String?> createOrUpdateStudentPerformanceRecord(String studentId, String storyId, String quizId, String type) async {
  try {
    var existingRecord = await FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('studentId', isEqualTo: studentId)
        .where('quizId', isEqualTo: quizId)
        .limit(1)
        .get();

    if (existingRecord.docs.isNotEmpty) {
      debugPrint("⚠️ StudentPerformance record already exists.");
      return existingRecord.docs.first.id; // ✅ Return existing document ID
    }

    // ✅ Create a new StudentPerformance record
    var newPerformanceRef = await FirebaseFirestore.instance.collection('StudentPerformance').add({
      'studentId': studentId,
      'storyId': storyId,
      'quizId': quizId,
      'startTime': Timestamp.now(),
      'type': type,
      'doneReading': false, // ✅ Set to false since student just started reading
      'miscueMarks': {}, // Empty field for teacher
      'totalScore': 0,
      'totalQuestions': 0,
    });

    debugPrint("✅ Created new StudentPerformance record with ID: ${newPerformanceRef.id}");
    return newPerformanceRef.id; // ✅ Return document ID

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
        title: const Text('Loading...', style: TextStyle(color: neutralColor)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green,
        shadowColor: const Color.fromARGB(255, 0, 0, 0),
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
      leading: null, // Explicitly set to null to remove the hamburger icon

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
                      future: FirebaseFirestore.instance.collection('Stories').doc(storyId).get(),
                      builder: (context, storySnapshot) {
                        if (storySnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (storySnapshot.hasError) {
                          return Center(child: Text('Error: ${storySnapshot.error}'));
                        } else if (!storySnapshot.hasData || !storySnapshot.data!.exists) {
                          return const Center(child: Text('Story not found'));
                        }

                        var storyData = storySnapshot.data;
                        var storyTitle = storyData?['title'] ?? 'No Title';
                        var isCompleted = quizDetails.containsKey(quizId);
                        var quizDetail = quizDetails[quizId] ?? {};
                        var score = quizDetail['score'] ?? '0/0';

                        bool isPostTestLocked = (type == "Post test" && !pretestCompleted);

                        return Card(
                          color: isCompleted ? Colors.amber : Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    storyTitle,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isCompleted)
                                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Type: $type", style: const TextStyle(color: Colors.white, fontSize: 14)),
                                if (isCompleted)
                                  Text("Score: $score", style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: (isPostTestLocked || isCompleted || _isProcessing)
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Start Assessment"),
                                          content: const Text("Are you sure you want to start this assessment now?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.green),
                                              child: const Text("Yes, Proceed"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm != true) return;

                                      setState(() => _isProcessing = true);

                                      DateTime startTime = DateTime.now();
                                      String? performanceId = await createOrUpdateStudentPerformanceRecord(
                                        widget.studentId,
                                        storyId,
                                        quizId,
                                        type,
                                      );

                                      if (performanceId == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("❌ Error creating StudentPerformance record.")),
                                        );
                                        setState(() => _isProcessing = false);
                                        return;
                                      }

                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StoryDetailAndQuizPage(
                                            storyId: storyId,
                                            quizId: quizId,
                                            startTime: startTime,
                                            studentId: widget.studentId,
                                            performanceId: performanceId,
                                          ),
                                        ),
                                      );

                                      setState(() => _isProcessing = false);
                                    },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.green,
                                backgroundColor: (isPostTestLocked || isCompleted) ? Colors.grey : Colors.white,
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
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    ),
  );
}
}