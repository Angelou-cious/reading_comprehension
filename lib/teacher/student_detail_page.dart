import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/models/student_model.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'package:auto_size_text/auto_size_text.dart';

class StudentDetailPage extends StatelessWidget {
  final Student student;

  const StudentDetailPage({super.key, required this.student});

  // Fetch student performance logs from Firestore
  Stream<QuerySnapshot> fetchStudentLogs() {
    return FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('studentId', isEqualTo: student.id)
        .snapshots();
  }

  // Fetch miscues for a specific performance record
  Future<int> fetchTotalMiscues(String performanceId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('MiscueRecords')
          .where('performanceId', isEqualTo: performanceId)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['totalMiscueScore'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching miscues: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF15A323),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Background(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileSection(),
              const Divider(height: 40, thickness: 1),
              const Text(
                'Performance Logs:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildPerformanceLogs()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Center(
      child: Column(
                children: [
                (student.profilePictureUrl != null && student.profilePictureUrl!.isNotEmpty)
            ? CircleAvatar(
                backgroundImage: NetworkImage(student.profilePictureUrl!),
                radius: 45,
              )
            : const Icon(
                Icons.account_circle,
                size: 90,
                color: Colors.black,
              ),

            const SizedBox(height: 10),
              Text(
                '${student.firstName} ${student.lastName}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
          AutoSizeText(
            'Email: ${student.email != null && student.email!.isNotEmpty ? student.email : 'N/A'}',
            style: const TextStyle(fontSize: 16),
            maxLines: 1,
            minFontSize: 10,
            overflow: TextOverflow.ellipsis,
          ),

          Text(
            'Grade: ${student.gradeLevel.isNotEmpty == true ? student.gradeLevel : 'N/A'}',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            'Gender: ${student.gender.isNotEmpty == true ? student.gender : 'N/A'}',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            'Grade: ${student.gradeLevel.isNotEmpty == true ? student.gradeLevel : 'N/A'}',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceLogs() {
    return StreamBuilder<QuerySnapshot>(
      stream: fetchStudentLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No records found.'));
        }
        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var logData = doc.data() as Map<String, dynamic>;
            return FutureBuilder<int>(
              future: fetchTotalMiscues(doc.id),
              builder: (context, miscuesSnapshot) {
                final miscues = miscuesSnapshot.data ?? 0;
                return _buildPerformanceCard(logData, miscues, doc.id);
              },
            );
          }).toList(),
        );
      },
    );
  }

Widget _buildPerformanceCard(
  Map<String, dynamic> logData,
  int miscues,
  String performanceId,
) {
  final date = logData['timestamp'] != null
      ? (logData['timestamp'] as Timestamp).toDate()
      : null;

  final int passageWordCount = logData['passageWordCount'] ?? 1;
  final double wordReadingScore = ((passageWordCount - miscues) / passageWordCount) * 100;
  final double comprehensionScore = (logData['totalScore'] != null && logData['totalQuestions'] != null)
      ? ((logData['totalScore'] / logData['totalQuestions']) * 100)
      : 0.0;
  final double readingSpeed = logData['readingSpeed'] ?? 0.0;

  final wordReadingLevel = _determineWordReadingLevel(wordReadingScore);
  final comprehensionLevel = _determineComprehensionLevel(comprehensionScore);
  final oralReadingProfile = _determineOralReadingProfile(wordReadingScore, comprehensionScore);

  String quizType = (logData['type'] ?? 'Unknown').toString().toUpperCase();

  bool showMore = false;
  Map<String, int> detailedMiscues = {};

  return StatefulBuilder(
    builder: (context, setState) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Quizzes').doc(logData['quizId']).get(),
        builder: (context, snapshot) {
          String quizTitle = 'Unknown Quiz';
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            final quizData = snapshot.data!.data() as Map<String, dynamic>?;
            quizTitle = quizData?['title'] ?? 'Unknown Quiz';
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quizTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Type: $quizType',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Date: ${date != null ? date.toLocal().toString().split(' ')[0] : 'N/A'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text('Word Reading Score: ${wordReadingScore.toStringAsFixed(2)}% ($wordReadingLevel)'),
                  Text('Comprehension Score: ${comprehensionScore.toStringAsFixed(2)}% ($comprehensionLevel)'),
                  Text('Reading Rate: ${readingSpeed.toStringAsFixed(2)} words per minute'),
                  Text('Reading Time: ${logData['readingTime'] != null ? _formatDuration(logData['readingTime']) : 'N/A'}'),
                  Text('Total Miscues: $miscues'),
                  Text('Oral Reading Profile: $oralReadingProfile', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () async {
                      if (!showMore) {
                        // Fetch miscues breakdown from Firestore
                        final miscueDoc = await FirebaseFirestore.instance
                            .collection('MiscueRecords')
                            .where('performanceId', isEqualTo: performanceId)
                            .limit(1)
                            .get();

                        if (miscueDoc.docs.isNotEmpty) {
                          final data = miscueDoc.docs.first.data();
                          if (data.containsKey('miscues')) {
                            final miscuesMap = Map<String, dynamic>.from(data['miscues']);
                            setState(() {
                              detailedMiscues = miscuesMap.map((key, value) => MapEntry(key, value as int));
                              showMore = true;
                            });
                          }
                        }
                      } else {
                        setState(() => showMore = false);
                      }
                    },
                    child: Text(showMore ? 'Hide' : 'See More'),
                  ),
                  if (showMore)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: detailedMiscues.entries.map((entry) {
                        return Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 14));
                      }).toList(),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}



  String _determineWordReadingLevel(double wordReadingScore) {
    if (wordReadingScore >= 97) {
      return "Independent";
    } else if (wordReadingScore >= 90) {
      return "Instructional";
    } else {
      return "Frustration";
    }
  }

  String _determineComprehensionLevel(double comprehensionScore) {
    if (comprehensionScore >= 80) {
      return "Independent";
    } else if (comprehensionScore >= 60) {
      return "Instructional";
    } else {
      return "Frustration";
    }
  }

  String _determineOralReadingProfile(double wordReadingScore, double comprehensionScore) {
    if (wordReadingScore >= 97 && comprehensionScore >= 80) {
      return "Independent";
    } else if (wordReadingScore >= 90 && comprehensionScore >= 60) {
      return "Instructional";
    } else {
      return "Frustration";
    }
  }
}
String _formatDuration(dynamic readingTime) {
  int seconds;
  if (readingTime is int) {
    seconds = readingTime;
  } else if (readingTime is double) {
    seconds = readingTime.toInt();
  } else {
    return 'Invalid';
  }

  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;

  if (minutes > 0) {
    return '${minutes}m ${remainingSeconds}s';
  } else {
    return '${remainingSeconds}s';
  }
}

