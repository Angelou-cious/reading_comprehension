import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background_reading.dart';
import 'quiz_page.dart';

class StoryDetailAndQuizPage extends StatefulWidget {
  final String storyId;
  final String quizId;
  final String studentId;

  const StoryDetailAndQuizPage({
    super.key,
    required this.storyId,
    required this.quizId,
    required this.studentId,
    required DateTime startTime, required String performanceId,
  });

  @override
  _StoryDetailAndQuizPageState createState() => _StoryDetailAndQuizPageState();
}

class _StoryDetailAndQuizPageState extends State<StoryDetailAndQuizPage> {
  bool _isProcessing = false;
  late Timer _timer;
  int _secondsElapsed = 0;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void stopTimer() {
    _timer.cancel();
  }

Future<void> updateReadingStatus() async {
  try {
    final performanceRef = FirebaseFirestore.instance.collection('StudentPerformance');
    final querySnapshot = await performanceRef
        .where('studentId', isEqualTo: widget.studentId)
        .where('quizId', isEqualTo: widget.quizId)
        .get();

    // ✅ Fetch quiz type (Pretest, Posttest, etc.)
    final quizSnapshot = await FirebaseFirestore.instance
        .collection('Quizzes')
        .doc(widget.quizId)
        .get();
    String quizType = quizSnapshot.data()?['type'] ?? 'unknown';

    if (querySnapshot.docs.isEmpty) {
      // ✅ If no record exists, create a new one and immediately set type
      await performanceRef.add({
        'studentId': widget.studentId,
        'quizId': widget.quizId,
        'type': quizType, // ✅ Assign type immediately
        'doneReading': true, // ✅ Mark as doneReading
        'miscuesMarked': false,
        'readingTime': _secondsElapsed,
        'passageWordCount': _wordCount,
        'timestamp': Timestamp.now(),
      });
      debugPrint('✅ New StudentPerformance record created.');
    } else {
      final performanceDoc = querySnapshot.docs.first;
      final data = performanceDoc.data();

      bool isAlreadyPosttest = data['type'] == "post test";

      // ✅ Ensure Posttest gets properly updated
      await performanceDoc.reference.update({
        'doneReading': true, // ✅ Update reading status
        'type': isAlreadyPosttest ? "post test" : quizType, // ✅ Ensure Posttest is not overwritten
        'readingTime': _secondsElapsed,
        'passageWordCount': _wordCount,
        'timestamp': Timestamp.now(),
      });

      debugPrint('✅ Existing StudentPerformance record updated.');
    }
  } catch (e) {
    debugPrint('❌ Error updating reading status: $e');
  }
}




  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int calculateWordCount(String content) {
    List<String> words = content
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return words.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STORY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF15A323),
      ),
      body: Background(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Stories').doc(widget.storyId).get(),
          builder: (context, storySnapshot) {
            if (!storySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var storyData = storySnapshot.data;
            var storyTitle = storyData?['title'] ?? 'No Title';
            var storyContent = storyData?['content'] ?? 'No Content';

            _wordCount = calculateWordCount(storyContent);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Time Elapsed: ${formatTime(_secondsElapsed)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    storyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          storyContent,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.bottomCenter,
                                                child:ElevatedButton(
                              onPressed: _isProcessing ? null : () async {
                                bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Start Quiz"),
                                    content: const Text("Are you sure you want to proceed to the quiz?"),
                                    actions: [
                                      TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red, // Text color
                                                ),
                                                child: const Text("Cancel"),
                                              ),

                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.green, // Text color
                                                ),
                                                child: const Text("Yes, Proceed"),
                                              ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      stopTimer();
      await updateReadingStatus();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizPage(
            quizId: widget.quizId,
            studentId: widget.studentId,
            readingTime: _secondsElapsed,
            passageWordCount: _wordCount,
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error navigating to quiz: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Please try again.")),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF15A323),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  child: _isProcessing
      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
      : const Text('Start Quiz'),
),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
