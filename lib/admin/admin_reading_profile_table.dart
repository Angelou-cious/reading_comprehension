import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:open_file/open_file.dart';

class AdminReadingProfileTable extends StatefulWidget {
  final String type;
  final String schoolYear;

  const AdminReadingProfileTable({
    super.key,
    required this.type,
    required this.schoolYear,
  });

  @override
  State<AdminReadingProfileTable> createState() => _AdminReadingProfileTableState();
}

class _AdminReadingProfileTableState extends State<AdminReadingProfileTable> {
  late Future<List<Map<String, dynamic>>> _tableDataFuture;
  bool _isDownloading = false;
  bool _permissionChecked = false;
  bool _isPermissionRequestRunning = false;

  String selectedTeacherId = 'All';
  String selectedGradeLevel = 'All';
  String selectedGender = 'All';

  List<String> teacherOptions = ['All'];
  Map<String, String> teacherNames = {}; // teacherId -> Full Name

  final List<String> columnTitles = [
    'Name', 'Sex', 'School', 'Teacher',
    'Level of Passage', 'Reading Time', 'Total Miscues',
    'Q1', 'Q2', 'Q3', 'Q4', 'Q5', 'Q6', 'Q7', 'Q8',
    'Score Marka', '% of Score', 'Word Reading Score', 'Reading Rate',
    'Comprehension Score', 'Word Reading Level', 'Comprehension Level',
    'Oral Reading Profile', 'Date Taken', 'School Year',
  ];

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
    _tableDataFuture = _fetchData();
    _checkStoragePermission();
  }
    @override
    void didUpdateWidget(covariant AdminReadingProfileTable oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.schoolYear != widget.schoolYear) {
        _tableDataFuture = _fetchData();
      }
    }

  Future<void> _checkStoragePermission() async {
    if (!Platform.isAndroid || _permissionChecked) return;
    if (_isPermissionRequestRunning) return;
    _isPermissionRequestRunning = true;

    try {
      var result = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      if (result[Permission.manageExternalStorage]?.isGranted == true) {
        _permissionChecked = true;
      }
    } catch (e) {
      debugPrint("Permission error: $e");
    } finally {
      _isPermissionRequestRunning = false;
    }
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Teachers')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final fullName = '${data['firstname']} ${data['lastname']}';
      teacherNames[doc.id] = fullName;
    }

    setState(() {
      teacherOptions = ['All', ...teacherNames.keys];
    });
  }

  Future<List<Map<String, dynamic>>> _fetchData() async {
    final firestore = FirebaseFirestore.instance;
    List<Map<String, dynamic>> rows = [];
    final students = await firestore.collection('Students').get();

    for (var studentDoc in students.docs) {
      final student = studentDoc.data();
      final studentId = studentDoc.id;

      // Apply filters
      if (selectedTeacherId != 'All' && student['teacherId'] != selectedTeacherId) continue;
      if (selectedGender != 'All' && student['gender'] != selectedGender) continue;
      if (selectedGradeLevel != 'All' && student['gradeLevel'].toString() != selectedGradeLevel) continue;

      final performances = await firestore
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: studentId)
          .orderBy('startTime', descending: true)
          .get();

      final filtered = performances.docs.where((doc) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        final docYear = data['schoolYear'];
        return type == widget.type.toLowerCase().replaceAll(' ', '') &&
               docYear != null &&
               docYear == widget.schoolYear;
      }).toList();

      if (filtered.isEmpty) continue;
      final perf = filtered.first.data();

      String schoolName = '';
      if (student['schoolId'] != null) {
        final schoolDoc = await firestore.collection('Schools').doc(student['schoolId']).get();
        schoolName = schoolDoc.data()?['name'] ?? '';
      }

      String teacherName = '';
      if (student['teacherId'] != null) {
        final teacherDoc = await firestore.collection('Teachers').doc(student['teacherId']).get();
        final t = teacherDoc.data();
        teacherName = '${t?['firstname'] ?? ''} ${t?['lastname'] ?? ''}';
      }

      String level = ''; 
      if (perf['storyId'] != null) {
        final story = await firestore.collection('Stories').doc(perf['storyId']).get();
        level = story.data()?['gradeLevel']?.toString() ?? '';
      } else if (perf['quizId'] != null) {
        final quiz = await firestore.collection('Quizzes').doc(perf['quizId']).get();
        level = quiz.data()?['gradeLevel']?.toString() ?? '';
      }

      DateTime? dt;
      if (perf['startTime'] is Timestamp) {
        dt = (perf['startTime'] as Timestamp).toDate();
      }

      Map<String, dynamic> row = {
        'Name': '${student['firstName']} ${student['lastName']}',
        'Sex': student['gender'] ?? '',
        'School': schoolName,
        'Teacher': teacherName,
        'Level of Passage': level,
        'Reading Time': perf['readingTime']?.toString() ?? '',
        'Total Miscues': perf['totalMiscues']?.toString() ?? '',
        'Q1': '', 'Q2': '', 'Q3': '', 'Q4': '', 'Q5': '', 'Q6': '', 'Q7': '', 'Q8': '',
        'Score Marka': '${perf['totalScore']} of ${perf['totalQuestions']}',
        '% of Score': perf['totalScore'] != null && perf['totalQuestions'] != null
            ? '${((perf['totalScore'] / perf['totalQuestions']) * 100).round()}%'
            : '',
        'Word Reading Score': '${perf['wordReadingScore'] ?? ''}',
        'Reading Rate': perf['readingSpeed'] != null ? '${perf['readingSpeed']} wpm' : '',
        'Comprehension Score': '${perf['comprehensionScore'] ?? ''}',
        'Word Reading Level': '${perf['wordReadingLevel'] ?? ''}',
        'Comprehension Level': '${perf['comprehensionLevel'] ?? ''}',
        'Oral Reading Profile': '${perf['oralReadingProfile'] ?? ''}',
        'Date Taken': dt != null ? dt.toIso8601String().split('T').first : '',
        'School Year': perf['schoolYear'] ?? '',
      };

      List<dynamic> answers = perf['answers'] ?? perf['responses'] ?? [];
      for (int i = 0; i < answers.length && i < 8; i++) {
        row['Q${i + 1}'] = answers[i]?.toString() ?? '';
      }

      rows.add(row);
    }

    return rows;
  }

  Future<void> _exportToCSV(List<Map<String, dynamic>> data) async {
    setState(() => _isDownloading = true);

    final buffer = StringBuffer();
    buffer.writeln(columnTitles.join(','));

    for (var row in data) {
      List<String> values = columnTitles.map((col) {
        String val = row[col]?.toString() ?? '';
        return '"${val.replaceAll('"', '""')}"';
      }).toList();
      buffer.writeln(values.join(','));
    }

    try {
      final dir = await getExternalStorageDirectory();
      final path = '${dir!.path}/AdminReadingProfile_${widget.type}_${widget.schoolYear}.csv';
      final file = File(path);
      await file.writeAsString(buffer.toString());
      OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }

    setState(() => _isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Horizontal scrollable dropdown filters
  

SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select Teacher',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedTeacherId,
              items: teacherOptions.map((id) {
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    id == 'All' ? 'All Teachers' : teacherNames[id] ?? 'Unknown',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTeacherId = value!;
                  _tableDataFuture = _fetchData();
                });
              },
            ),
          ),
        ),
      ),
      Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Grade Level',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedGradeLevel,
              items: ['All', '5', '6'].map((grade) {
                return DropdownMenuItem(
                  value: grade,
                  child: Text(
                    grade == 'All' ? 'All Grades' : 'Grade $grade',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGradeLevel = value!;
                  _tableDataFuture = _fetchData();
                });
              },
            ),
          ),
        ),
      ),
      Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedGender,
              items: ['All', 'Male', 'Female'].map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: Text(
                    gender == 'All' ? 'All Genders' : gender,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGender = value!;
                  _tableDataFuture = _fetchData();
                });
              },
            ),
          ),
        ),
      ),
    ],
  ),
),




          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _tableDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(18.0),
                  child: Text('No records found.'),
                );
              }

              final rows = snapshot.data!;
              return Column(
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: columnTitles.length * 120,
                          child: Scrollbar(
                            controller: _verticalController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _verticalController,
                              itemCount: rows.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Container(
                                    color: const Color.fromRGBO(21, 163, 35, 0.11),
                                    child: Row(
                                      children: columnTitles.map((col) {
                                        return Container(
                                          width: 120,
                                          padding: const EdgeInsets.all(10),
                                          child: AutoSizeText(
                                            col,
                                            maxLines: 1,
                                            minFontSize: 9,
                                            maxFontSize: 13,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                } else {
                                  final row = rows[index - 1];
                                  return Container(
                                    color: Colors.white.withOpacity(0.92),
                                    child: Row(
                                      children: columnTitles.map((col) {
                                        return Container(
                                          width: 120,
                                          padding: const EdgeInsets.all(8),
                                          child: AutoSizeText(
                                            row[col] ?? '',
                                            maxLines: 2,
                                            minFontSize: 9,
                                            maxFontSize: 13,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isDownloading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text("Download as CSV"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15A323),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () async {
                        if (!_permissionChecked) await _checkStoragePermission();
                        if (_permissionChecked) {
                          final rows = await _tableDataFuture;
                          await _exportToCSV(rows);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Storage permission is required.")),
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
