import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'dart:ui';
import 'package:reading_comprehension/utils/school_year_util.dart';

Widget glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

class AssignStoryQuizPage extends StatefulWidget {
  final String teacherId;
  const AssignStoryQuizPage({super.key, required this.teacherId});

  @override
  _AssignStoryQuizPageState createState() => _AssignStoryQuizPageState();
}

class _AssignStoryQuizPageState extends State<AssignStoryQuizPage> {
  List<String> selectedStudents = [];
  String searchQuery = '';
  String? selectedGradeLevel = 'All';
  String? selectedStoryType;
  String? selectedPassageSet;
  String? selectedStoryId;
  Map<String, dynamic>? selectedStoryQuiz;
  List<Map<String, dynamic>> cachedStories = [];
  bool selectAll = false;
  bool _loading = false;

  // Cache loaded pretest student IDs and assigned pretest story IDs to avoid repeat queries
  Set<String> pretestStudentIds = {};
  Set<String> assignedPretestStoryIds = {};

  /// NEW: Load all student pretest data in one query, not N queries
  Future<void> _preloadPretestData() async {
    // Get all students assigned to this teacher
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('Students')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();

    List<String> allStudentIds = studentsSnapshot.docs.map((doc) => doc.id).toList();
    pretestStudentIds.clear();
    assignedPretestStoryIds.clear();

    // BATCH read all subcollections with a single query per batch of students
    for (int i = 0; i < allStudentIds.length; i += 10) {
      final batchIds = allStudentIds.skip(i).take(10).toList();

      // Fetch each batch in parallel
      final assignedFutures = batchIds.map((id) {
        return FirebaseFirestore.instance
            .collection('Students')
            .doc(id)
            .collection('AssignedAssessments')
            .where('type', isEqualTo: 'Pretest')
            .get();
      }).toList();

      final assignedSnapshots = await Future.wait(assignedFutures);
      for (int j = 0; j < assignedSnapshots.length; j++) {
        if (assignedSnapshots[j].docs.isNotEmpty) {
          pretestStudentIds.add(batchIds[j]);
          assignedPretestStoryIds.add(assignedSnapshots[j].docs.first['storyId']);
        }
      }
    }
  }

  /// Only students who don't have a Pretest assigned
  Future<List<String>> _getStudentIdsWithoutPretest() async {
    await _preloadPretestData();
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('Students')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();
    List<String> eligibleIds = [];
    for (var studentDoc in studentsSnapshot.docs) {
      if (!pretestStudentIds.contains(studentDoc.id)) {
        eligibleIds.add(studentDoc.id);
      }
    }
    return eligibleIds;
  }

  /// Return all Pretest story IDs already assigned (for filtering stories)
  Future<List<String>> _getAllAssignedPretestStoryIds() async {
    await _preloadPretestData();
    return assignedPretestStoryIds.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Story & Quiz', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF15A323),
        centerTitle: true,
      ),
      body: Background(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Story Type',
                        value: selectedStoryType,
                        items: ['Custom', 'Post test', 'Pretest'],
                        onChanged: (value) {
                          setState(() {
                            selectedStoryType = value;
                            selectedPassageSet = null;
                            selectedStoryQuiz = null;
                            cachedStories.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Passage Set',
                        value: selectedPassageSet,
                        items: ['A', 'B', 'C', 'D'],
                        onChanged: (value) {
                          setState(() {
                            selectedPassageSet = value;
                            selectedStoryQuiz = null;
                            cachedStories.clear();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStoryQuizDropdown(),
                const Divider(thickness: 2, color: Colors.grey),
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 8),
                _buildSelectAllCheckbox(),
                const SizedBox(height: 8),
                SizedBox(height: 300, child: _buildStudentList()),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: validateBeforeAssigning,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15A323),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Assign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildStoryQuizDropdown() {
    if (selectedStoryType == null || selectedPassageSet == null) {
      return const Center(
        child: Text(
          'Please select Story Type and Passage Set first.',
          style: TextStyle(color: Colors.red, fontSize: 14),
        ),
      );
    }

    // For Pretest, filter out stories already assigned as Pretest
    return FutureBuilder(
      future: selectedStoryType == 'Pretest'
          ? Future.wait([
              FirebaseFirestore.instance
                  .collection('Stories')
                  .where('type', isEqualTo: selectedStoryType!.toLowerCase())
                  .where('set', isEqualTo: 'Set ${selectedPassageSet!.toUpperCase()}')
                  .get(),
              _getAllAssignedPretestStoryIds(),
            ])
          : Future.wait([
              FirebaseFirestore.instance
                  .collection('Stories')
                  .where('type', isEqualTo: selectedStoryType!.toLowerCase())
                  .where('set', isEqualTo: 'Set ${selectedPassageSet!.toUpperCase()}')
                  .get(),
            ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData ||
            snapshot.data!.isEmpty ||
            (snapshot.data!.first as QuerySnapshot).docs.isEmpty) {
          return const Center(
            child: Text(
              'No stories available for the selected filters.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        final storyDocs = (snapshot.data!.first as QuerySnapshot).docs;
        final assignedStoryIds =
            selectedStoryType == 'Pretest' && snapshot.data!.length > 1
                ? snapshot.data![1] as List<String>
                : [];

      final filtered = storyDocs
          .map<Map<String, dynamic>>((doc) => {
            'storyId': doc.id,
            'title': doc['title'],
            'gradeLevel': doc['gradeLevel'],
          })
          .toList();

      filtered.sort((a, b) => a['title'].toString().toLowerCase().compareTo(b['title'].toString().toLowerCase()));


        cachedStories = filtered;

        return _buildStoryDropdownField(cachedStories);
      },
    );
  }

  Widget _buildStoryDropdownField(List<Map<String, dynamic>> stories) {
    return DropdownButtonFormField<String>(
      value: selectedStoryId,
      decoration: const InputDecoration(
        labelText: 'Select Story',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: stories.map((story) {
        return DropdownMenuItem<String>(
          value: story['storyId'],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                story['title'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${story['gradeLevel'] ?? "?"}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedStoryId = value;
          selectedStoryQuiz =
              stories.firstWhere((story) => story['storyId'] == value);
        });
      },
      selectedItemBuilder: (context) {
        return stories.map((story) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    story['title'],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${story['gradeLevel'] ?? "?"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      menuMaxHeight: 300.0,
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) {
        setState(() {
          searchQuery = value.toLowerCase();
        });
      },
      decoration: InputDecoration(
        labelText: 'Search Students',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSelectAllCheckbox() {
    return CheckboxListTile(
      title: const Text('Select All'),
      value: selectAll,
      onChanged: (isChecked) async {
        setState(() {
          selectAll = isChecked ?? false;
        });

        if (selectAll) {
          if (selectedStoryType == 'Pretest') {
            final eligibleIds = await _getStudentIdsWithoutPretest();
            setState(() {
              selectedStudents = eligibleIds;
            });
          } else {
            final snapshot = await FirebaseFirestore.instance
                .collection('Students')
                .where('teacherId', isEqualTo: widget.teacherId)
                .get();
            setState(() {
              selectedStudents = snapshot.docs.map((doc) => doc.id).toList();
            });
          }
        } else {
          setState(() {
            selectedStudents.clear();
          });
        }
      },
    );
  }

  Widget _buildStudentList() {
    if (selectedStoryType == 'Pretest') {
      // Only show students WITHOUT Pretest
      return FutureBuilder<List<String>>(
        future: _getStudentIdsWithoutPretest(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final eligibleIds = snapshot.data!;
          if (eligibleIds.isEmpty) {
            return const Center(child: Text('All students already have a Pretest assigned.'));
          }

          // Firestore whereIn limitation: split into chunks of 10
          List<Widget> studentLists = [];
          for (int i = 0; i < eligibleIds.length; i += 10) {
            final chunk = eligibleIds.skip(i).take(10).toList();
            studentLists.add(
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Students')
                    .where(FieldPath.documentId, whereIn: chunk)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final students = snap.data!.docs.where((student) {
                    final name = '${student['firstName']} ${student['lastName']}'.toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final name = '${student['firstName']} ${student['lastName']}';

                      return CheckboxListTile(
                        title: Text(name),
                        value: selectedStudents.contains(student.id),
                        onChanged: (isSelected) {
                          setState(() {
                            if (isSelected == true) {
                              selectedStudents.add(student.id);
                            } else {
                              selectedStudents.remove(student.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            );
          }
          return Column(children: studentLists);
        },
      );
    } else {
      // Normal student list
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Students')
            .where('teacherId', isEqualTo: widget.teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data!.docs.where((student) {
            final name = '${student['firstName']} ${student['lastName']}'.toLowerCase();
            return name.contains(searchQuery);
          }).toList();

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final name = '${student['firstName']} ${student['lastName']}';

              return CheckboxListTile(
                title: Text(name),
                value: selectedStudents.contains(student.id),
                onChanged: (isSelected) {
                  setState(() {
                    if (isSelected == true) {
                      selectedStudents.add(student.id);
                    } else {
                      selectedStudents.remove(student.id);
                    }
                  });
                },
              );
            },
          );
        },
      );
    }
  }

  void validateBeforeAssigning() async {
    if (selectedStoryQuiz == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid story and quiz.')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final quizQuerySnapshot = await FirebaseFirestore.instance
          .collection('Quizzes')
          .where('storyId', isEqualTo: selectedStoryQuiz!['storyId'])
          .get();

      if (quizQuerySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No quiz found for the selected story.')),
        );
        return;
      }

      assignQuizToStudents();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void assignQuizToStudents() async {
    if (selectedStoryQuiz == null || selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a story, quiz, and students.')),
      );
      return;
    }

    final storyId = selectedStoryQuiz!['storyId'];
    final storyTitle = selectedStoryQuiz!['title'];

    setState(() {
      _loading = true;
    });

    try {
      // Fetch the quizId for the selected story
      final quizQuerySnapshot = await FirebaseFirestore.instance
          .collection('Quizzes')
          .where('storyId', isEqualTo: storyId)
          .get();

      if (quizQuerySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No quiz found for the selected story.')),
        );
        return;
      }

      final quizId = quizQuerySnapshot.docs.first.id;

      // Loop through the selected students
      for (var studentId in selectedStudents) {
        // Fetch the grade level dynamically from the student's document
        final studentDoc = await FirebaseFirestore.instance
            .collection('Students')
            .doc(studentId)
            .get();

        if (!studentDoc.exists) {
          print('Student $studentId does not exist.');
          continue;
        }
        final schoolYear = await getCurrentSchoolYear();
        final studentData = studentDoc.data()!;
        final gradeLevel = studentData['gradeLevel'] ?? 'Unknown';

        // Assign the story and quiz to the student
        await FirebaseFirestore.instance
            .collection('Students')
            .doc(studentId)
            .collection('AssignedAssessments')
            .add({
          'storyId': storyId,
          'storyTitle': storyTitle,
          'quizId': quizId,
          'quizTitle': selectedStoryQuiz!['title'], // Include quiz title
          'assignedAt': Timestamp.now(),
          'teacherId': widget.teacherId,
          'assignedGradeLevel': gradeLevel, // Dynamically fetch grade level
          'type': selectedStoryType,
          'set': selectedPassageSet,
          'schoolYear': schoolYear,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment successful!')),
      );

      setState(() {
        selectedStudents.clear();
        selectAll = false;
      });
    } catch (e) {
      print("Error assigning quiz: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error assigning quiz. Please try again.')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}
