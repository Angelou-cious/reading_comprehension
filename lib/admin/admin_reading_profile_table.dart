import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:open_file/open_file.dart';

class AdminReadingProfileTable extends StatefulWidget {
  final String type;

  const AdminReadingProfileTable({super.key, required this.type, required String schoolYear});

  @override
  State<AdminReadingProfileTable> createState() => _AdminReadingProfileTableState();
}

class _AdminReadingProfileTableState extends State<AdminReadingProfileTable> {
  late Future<List<Map<String, dynamic>>> _tableDataFuture;
  bool _isDownloading = false;
  bool _permissionChecked = false;
  bool _isPermissionRequestRunning = false;
  List<String> _schoolYears = [];
  String? selectedSchoolYear;

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
    _loadSchoolYears();
    _checkStoragePermission();
  }

  Future<void> _loadSchoolYears() async {
    final snapshot = await FirebaseFirestore.instance.collection('StudentPerformance').get();
    final years = snapshot.docs
    .map((doc) => doc.data())
    .where((data) => data.containsKey('schoolYear') && data['schoolYear'].toString().trim().isNotEmpty)
    .map((data) => data['schoolYear'].toString())
    .toSet()
    .toList();

    years.removeWhere((year) => year.isEmpty);
    years.sort((a, b) => b.compareTo(a)); // Latest first

    setState(() {
      _schoolYears = years;
      if (_schoolYears.isNotEmpty) {
        selectedSchoolYear = _schoolYears.first;
        _tableDataFuture = _fetchData();
      }
    });
  }

  Future<void> _checkStoragePermission() async {
    if (!Platform.isAndroid || _permissionChecked) {
      _permissionChecked = true;
      return;
    }

    if (_isPermissionRequestRunning) return;
    _isPermissionRequestRunning = true;

    try {
      var storageStatus = await Permission.storage.status;

      if (await Permission.manageExternalStorage.isGranted) {
        _permissionChecked = true;
      } else {
        var result = await [
          Permission.storage,
          Permission.manageExternalStorage,
        ].request();

        if (result[Permission.manageExternalStorage]?.isGranted == true) {
          _permissionChecked = true;
        }
      }
    } catch (e) {
      debugPrint("Permission error: $e");
    } finally {
      _isPermissionRequestRunning = false;
      if (mounted) setState(() {});
    }
  }
Future<List<Map<String, dynamic>>> _fetchData() async {
  final firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> rows = [];
  final students = await firestore.collection('Students').get();

  for (var studentDoc in students.docs) {
    final student = studentDoc.data();
    final studentId = studentDoc.id;

    final performances = await firestore
        .collection('StudentPerformance')
        .where('studentId', isEqualTo: studentId)
        .orderBy('startTime', descending: true)
        .get();

    // FILTER safely here in Dart (not Firestore)
    final filtered = performances.docs.where((doc) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase().replaceAll(' ', '');
      final docSchoolYear = data['schoolYear'];
      return type == widget.type.toLowerCase().replaceAll(' ', '') &&
          docSchoolYear != null &&
          docSchoolYear == selectedSchoolYear;
    }).toList();

    if (filtered.isEmpty) continue;
    final perf = filtered.first.data();


      String schoolName = '';
      if (student['schoolId'] != null) {
        final schoolDoc = await firestore.collection('Schools').doc(student['schoolId']).get();
        if (schoolDoc.exists) {
          schoolName = schoolDoc.data()?['name'] ?? '';
        }
      }

      String teacherName = '';
      if (student['teacherId'] != null) {
        final teacherDoc = await firestore.collection('Teachers').doc(student['teacherId']).get();
        if (teacherDoc.exists) {
          final t = teacherDoc.data();
          teacherName = '${t?['firstname'] ?? ''} ${t?['lastname'] ?? ''}';
        }
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
        'schoolYear': perf['schoolYear'] ?? '',
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
      if (dir == null) throw 'No external storage directory available';
      final path = '${dir.path}/AdminReadingProfile_${widget.type}_$selectedSchoolYear.csv';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_schoolYears.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text('Select School Year: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedSchoolYear,
                    items: _schoolYears.map((year) {
                      return DropdownMenuItem(value: year, child: Text(year));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedSchoolYear = val;
                          _tableDataFuture = _fetchData();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          if (selectedSchoolYear != null)
           SizedBox(
                height: MediaQuery.of(context).size.height * 0.6, // or any height you prefer
                child: FutureBuilder<List<Map<String, dynamic>>>(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${widget.type[0].toUpperCase()}${widget.type.substring(1)} Results for $selectedSchoolYear',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
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
                        Center(
                          child: ElevatedButton.icon(
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
                        ),
                    ],
                  );
                },
              ),
            )
          else
            const Center(child: Text("No school year selected")),
        ],
      ),
    );
  }
}
