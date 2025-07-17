import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phil/models/student_model.dart';
import 'package:phil/teacher/mark_miscues_page.dart';
import 'package:phil/teacher/student_detail_page.dart';
import 'package:phil/widgets/background.dart';
import 'package:auto_size_text/auto_size_text.dart';

class StudentListPage extends StatefulWidget {
  final String teacherId;

  const StudentListPage({super.key, required this.teacherId});

  @override
  _StudentListPageState createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  String _searchText = '';
  String _selectedGrade = 'All';
  String _selectedGender = 'All';
  bool _isAscending = true;

  Future<Map<String, String?>> _fetchQuizAndStoryIds(String studentId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: studentId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type']?.toString().toLowerCase() ?? '';

        // Check if miscue exists in the ROOT MiscueRecords collection
        final miscues = await FirebaseFirestore.instance
            .collection('MiscueRecords')
            .where('performanceId', isEqualTo: doc.id)
            .limit(1)
            .get();

        // If no miscue yet for this performance
        if (miscues.docs.isEmpty) {
          return {
            'quizId': data['quizId'],
            'storyId': data['storyId'],
            'type': type,
            'performanceId': doc.id,
          };
        } else {
          debugPrint("✅ $type already marked.");
        }
      }

      return {'error': 'Pretest and Posttest miscues already completed'};
    } catch (e) {
      debugPrint('❌ Error fetching StudentPerformance: $e');
      return {'error': 'Error fetching StudentPerformance: $e'};
    }
  }

  Future<bool> _isMiscueCompleted(String studentId) async {
    final performanceSnapshot = await FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('studentId', isEqualTo: studentId)
        .get();

    int completed = 0;

    for (var doc in performanceSnapshot.docs) {
      final miscues = await FirebaseFirestore.instance
          .collection('MiscueRecords')
          .where('performanceId', isEqualTo: doc.id)
          .limit(1)
          .get();

      if (miscues.docs.isNotEmpty) {
        completed++;
      }
    }

    return completed >= 2; // ✅ true if pretest and posttest completed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student List',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF15A323),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Background(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Search Students',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGrade,
                      onChanged: (value) {
                        setState(() {
                          _selectedGrade = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Select Grade',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      items: <String>['All', '5', '6']
                          .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text('Grade $value'),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Select Gender',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      items: <String>['All', 'Male', 'Female']
                          .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      setState(() {
                        _isAscending = !_isAscending;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Students')
                    .where('teacherId', isEqualTo: widget.teacherId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading students.'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No students found.'));
                  }

                  var students = snapshot.data!.docs.map((doc) {
                    return Student.fromFirestore(doc);
                  }).toList();

                  if (_searchText.isNotEmpty) {
                    students = students.where((student) {
                      final fullName =
                          '${student.firstName} ${student.lastName}'
                              .toLowerCase();
                      return fullName.contains(_searchText.toLowerCase());
                    }).toList();
                  }

                  if (_selectedGrade != 'All') {
                    students = students.where((student) {
                      return student.gradeLevel == _selectedGrade;
                    }).toList();
                  }

                  if (_selectedGender != 'All') {
                    students = students.where((student) {
                      return student.gender == _selectedGender;
                    }).toList();
                  }

                  students.sort((a, b) {
                    final comparison = (a.firstName).compareTo(b.firstName);
                    return _isAscending ? comparison : -comparison;
                  });

                  return ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final studentId = student.id;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        margin: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 10.0,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 12.0,
                          ),

                          title: AutoSizeText(
                            '${student.firstName} ${student.lastName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17, // default font
                            ),
                            maxLines: 2,
                            minFontSize: 12, // will shrink down to 12 if needed
                            overflow: TextOverflow
                                .ellipsis, // add ellipsis if still too long
                          ),

                          subtitle: AutoSizeText(
                            'Grade: ${student.gradeLevel}\nGender: ${student.gender}',
                            style: const TextStyle(fontSize: 15),
                            maxLines: 2,
                            minFontSize: 5,
                          ),
                          trailing: FutureBuilder<bool>(
                            future: _isMiscueCompleted(student.id),
                            builder: (context, snapshot) {
                              final isComplete = snapshot.data == true;

                              return ElevatedButton(
                                onPressed: isComplete
                                    ? null
                                    : () async {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF15A323),
                                            ),
                                          ),
                                        );

                                        try {
                                          Map<String, String?> ids =
                                              await _fetchQuizAndStoryIds(
                                                student.id,
                                              );
                                          String? quizId = ids['quizId'];
                                          String? storyId = ids['storyId'];
                                          String? type = ids['type'];
                                          String? performanceId =
                                              ids['performanceId'];

                                          Navigator.of(
                                            context,
                                          ).pop(); // ✅ Close loading

                                          if (quizId == null ||
                                              storyId == null ||
                                              type == null ||
                                              performanceId == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "⚠️ Cannot mark miscues. Student hasn't started reading yet.",
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  MarkMiscuesPage(
                                                    studentId: student.id,
                                                    type: type,
                                                    performanceId:
                                                        performanceId,
                                                  ),
                                            ),
                                          );
                                        } catch (e) {
                                          Navigator.of(
                                            context,
                                          ).pop(); // ✅ Ensure dialog closes on error
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('❌ Error: $e'),
                                            ),
                                          );
                                        }

                                        // fetch and navigate logic...
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isComplete
                                      ? Colors.grey
                                      : const Color(0xFF15A323),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      isComplete ? 'Completed' : 'Mark Miscue',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          leading: CircleAvatar(
                            radius: 25,
                            backgroundImage:
                                (student.profilePictureUrl).isNotEmpty
                                ? NetworkImage(student.profilePictureUrl)
                                : const AssetImage(
                                        'assets/images/default_profile.png',
                                      )
                                      as ImageProvider,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StudentDetailPage(student: student),
                              ),
                            );
                          },
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
    );
  }
}
