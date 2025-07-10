import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background_reading.dart';
import 'package:reading_comprehension/student/student_home_page.dart';
import 'package:reading_comprehension/utils/school_year_util.dart';

class QuizPage extends StatefulWidget {
  final String quizId;
  final String studentId;
  final int readingTime;
  final int passageWordCount;

  const QuizPage({
    super.key,
    required this.quizId,
    required this.studentId,
    required this.readingTime,
    required this.passageWordCount,
  });

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  bool _isSubmitting = false;
  List<Map<String, dynamic>> questions = [];
  int currentIndex = 0;
  int score = 0;
  String? selectedOption;
  bool isLoading = true;
  String quizType = "Unknown";

  // NEW: Track student answers (as choices: 'A', 'B', etc)
  List<String> studentAnswers = [];

  @override
  void initState() {
    super.initState();
    _checkEligibilityAndLoadQuiz();
  }

  Future<void> _checkEligibilityAndLoadQuiz() async {
    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('Students')
          .doc(widget.studentId)
          .get();

      if (!studentSnapshot.exists || studentSnapshot.data() == null) {
        throw Exception('Student record not found.');
      }

      final studentData = studentSnapshot.data()!;
      final pretestCompleted = studentData['pretestCompleted'] ?? false;
      final posttestAssigned = studentData['posttestAssigned'] ?? false;

      if (quizType.toLowerCase() == 'pretest' && pretestCompleted) {
        throw Exception('Pretest already completed. You are not eligible to retake it.');
      }

      if (quizType.toLowerCase() == 'posttest' && (!pretestCompleted || !posttestAssigned)) {
        throw Exception('You are not eligible for the posttest.');
      }

      await loadQuiz();
    } catch (e) {
      _showErrorAndExit(e.toString());
    }
  }

  Future<void> loadQuiz() async {
    try {
      var quizSnapshot = await FirebaseFirestore.instance.collection('Quizzes').doc(widget.quizId).get();
      var quizData = quizSnapshot.data();

      if (quizData != null) {
        quizType = quizData['type'] ?? "Unknown";
        if (quizData.containsKey('questions')) {
          setState(() {
            questions = List<Map<String, dynamic>>.from(quizData['questions']);
            isLoading = false;
          });
        } else {
          throw Exception('No questions found in quiz data.');
        }
      } else {
        throw Exception('Quiz not found.');
      }
    } catch (e) {
      _showErrorAndExit('Error loading quiz: $e');
    }
  }

  void _showErrorAndExit(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    Navigator.pop(context);
  }

  void submitAnswer() async {
    if (selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an option.')),
      );
      return;
    }

    if (_isSubmitting) return;

    // NEW: Save the picked answer before moving on!
    studentAnswers.add(selectedOption!);

    if (questions[currentIndex]['correctAnswer'] == selectedOption) {
      score++;
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedOption = null;
      });
    } else {
      setState(() {
        _isSubmitting = true;
      });

      await showResult();

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> showResult() async {
    double readingTimeInMinutes = widget.readingTime / 60;
    double readingSpeed = widget.passageWordCount / (readingTimeInMinutes > 0 ? readingTimeInMinutes : 1);
    double comprehensionScorePercentage = (score / questions.length) * 100;

    var miscuesSnapshot = await FirebaseFirestore.instance
        .collection('MiscueRecords')
        .where('studentId', isEqualTo: widget.studentId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    int totalMiscues = 0;
    if (miscuesSnapshot.docs.isNotEmpty) {
      totalMiscues = miscuesSnapshot.docs.first.data()['totalMiscueScore'] ?? 0;
    }

    double wordReadingScore = ((widget.passageWordCount - totalMiscues) / widget.passageWordCount) * 100;
    String comprehensionLevel = determineComprehensionLevel(comprehensionScorePercentage);
    String oralReadingProfile = determineOralReadingProfile(wordReadingScore, comprehensionLevel);

    await _storeQuizResults(readingSpeed, comprehensionScorePercentage, oralReadingProfile, totalMiscues);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Result'),
        content: Text(
          'Reading Speed: ${readingSpeed.toStringAsFixed(2)} words per minute\n'
          'Word Reading Score: ${wordReadingScore.toStringAsFixed(2)}%\n'
          'Comprehension Score: $score/${questions.length} (${comprehensionScorePercentage.toStringAsFixed(2)}%)\n'
          'Oral Reading Profile: $oralReadingProfile',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => StudentHomePage(studentId: widget.studentId),
                ),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _storeQuizResults(
    double readingSpeed,
    double comprehensionScorePercentage,
    String comprehensionLevel,
    int miscues,
  ) async {
    try {
      final quizSnapshot = await FirebaseFirestore.instance
          .collection('Quizzes')
          .doc(widget.quizId)
          .get();

      String quizType = quizSnapshot.data()?['type'] ?? 'unknown';

      double passageWordCount = widget.passageWordCount.toDouble();
      double wordReadingScore = ((passageWordCount - miscues) / passageWordCount) * 100;

      String wordReadingLevel;
      if (wordReadingScore >= 97) {
        wordReadingLevel = "Independent";
      } else if (wordReadingScore >= 90) {
        wordReadingLevel = "Instructional";
      } else {
        wordReadingLevel = "Frustration";
      }

      String oralReadingProfile = determineOralReadingProfile(wordReadingScore, comprehensionLevel);
      final performanceRef = FirebaseFirestore.instance.collection('StudentPerformance');
      final querySnapshot = await performanceRef
          .where('studentId', isEqualTo: widget.studentId)
          .where('quizId', isEqualTo: widget.quizId)
          .get();
      final schoolYear = await getCurrentSchoolYear();
      
      if (querySnapshot.docs.isEmpty) {
        await performanceRef.add({
          'studentId': widget.studentId,
          'quizId': widget.quizId,
          'readingTime': widget.readingTime.toDouble(),
          'readingSpeed': readingSpeed.toDouble(),
          'comprehensionScore': comprehensionScorePercentage.toDouble(),
          'wordReadingScore': wordReadingScore.toDouble(),
          'totalMiscues': miscues,
          'comprehensionLevel': comprehensionLevel,
          'wordReadingLevel': wordReadingLevel,
          'oralReadingProfile': oralReadingProfile,
          'type': quizType,
          'totalScore': score,
          'totalQuestions': questions.length,
          'answers': studentAnswers, // NEW: save answers!
          'timestamp': Timestamp.now(),
          'schoolYear': schoolYear,
        });
      } else {
        await querySnapshot.docs.first.reference.update({
          'readingTime': widget.readingTime.toDouble(),
          'readingSpeed': readingSpeed.toDouble(),
          'comprehensionScore': comprehensionScorePercentage.toDouble(),
          'wordReadingScore': wordReadingScore.toDouble(),
          'totalMiscues': miscues,
          'comprehensionLevel': comprehensionLevel,
          'wordReadingLevel': wordReadingLevel,
          'oralReadingProfile': oralReadingProfile,
          'type': quizType,
          'totalScore': score,
          'totalQuestions': questions.length,
          'answers': studentAnswers, // NEW: save answers!
          'timestamp': Timestamp.now(),
          'schoolYear': schoolYear,
        });
      }

      if (quizType.toLowerCase() == "pretest") {
        await FirebaseFirestore.instance.collection('Students').doc(widget.studentId).update({
          'pretestCompleted': true,
          'posttestAssigned': true,
        });
      }
    } catch (e) {
      debugPrint('❌ Error storing quiz results: $e');
    }
  }

  String determineComprehensionLevel(double score) {
    if (score >= 80) return "Independent";
    if (score >= 59) return "Instructional";
    return "Frustration";
  }

  String determineOralReadingProfile(double wordReadingScore, String comprehensionLevel) {
    if (wordReadingScore >= 97 && comprehensionLevel == "Independent") return "Independent";
    if (wordReadingScore >= 90 && (comprehensionLevel == "Instructional" || comprehensionLevel == "Independent")) return "Instructional";
    return "Frustration";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    var question = questions[currentIndex];

    return WillPopScope(
      onWillPop: () async => false,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text(
                'Quiz',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
              ),
              centerTitle: true,
              backgroundColor: const Color(0xFF15A323),
            ),
            body: Background(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      '${currentIndex + 1}. ${question['question'] ?? 'No question provided'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 30, thickness: 0.5, color: Colors.black),
                    Column(
                      children: (question['answers'] as Map<String, dynamic>).entries.map((entry) {
                        String optionKey = entry.key;
                        String optionValue = entry.value;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: optionKey,
                                groupValue: selectedOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedOption = value;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(optionValue, style: const TextStyle(fontSize: 16)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            floatingActionButton: ElevatedButton(
              onPressed: submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15A323),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      currentIndex == questions.length - 1 ? 'SUBMIT' : 'NEXT',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          ),
        ],
      ),
    );
  }
}
