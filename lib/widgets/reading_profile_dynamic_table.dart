import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:open_file/open_file.dart';
import 'package:reading_comprehension/utils/school_year_util.dart';

class ReadingProfileGlassTable extends StatefulWidget {
  final String teacherId;
  final String type; // "pretest", "posttest", etc.

  const ReadingProfileGlassTable({
    super.key,
    required this.teacherId,
    required this.type,
  });

  @override
  State<ReadingProfileGlassTable> createState() => _ReadingProfileGlassTableState();
}

class _ReadingProfileGlassTableState extends State<ReadingProfileGlassTable> {
  late Future<List<Map<String, dynamic>>> _tableDataFuture;
  bool _isDownloading = false;
  bool _permissionChecked = false;

  final List<String> columnTitles = [
    'Name', 'Sex', 'Level of Passage', 'Reading Time', 'Total Miscues',
    'Q1', 'Q2', 'Q3', 'Q4', 'Q5', 'Q6', 'Q7', 'Q8',
    'Score Marka', '% of Score', 'Word Reading Score', 'Reading Rate',
    'Comprehension Score', 'Word Reading Level', 'Comprehension Level',
    'Oral Reading Profile', 'Date Taken',
  ];

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tableDataFuture = _fetchTableData();
    _checkStoragePermission();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _checkStoragePermission() async {
    if (!Platform.isAndroid) {
      setState(() {
        _permissionChecked = true;
      });
      return;
    }
    var status = await Permission.storage.status;
    setState(() {
      _permissionChecked = true;
    });
  }

  // Removed unused method '_requestStoragePermission'.

  String _normalizeType(String s) => s.toLowerCase().replaceAll(' ', '');

  Future<List<Map<String, dynamic>>> _fetchTableData() async {
  final firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> tableRows = [];
  try {
    final studentsSnap = await firestore
        .collection('Students')
        .where('teacherId', isEqualTo: widget.teacherId)
        .where('schoolYear', isEqualTo: await getCurrentSchoolYear())
        .get();

    for (var studentDoc in studentsSnap.docs) {
      final student = studentDoc.data();
      final studentId = studentDoc.id;
      final perfSnap = await firestore
      
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: studentId)
          .where('schoolYear', isEqualTo: await getCurrentSchoolYear())
          .orderBy('startTime', descending: true)
          .get();

      final normWidgetType = _normalizeType(widget.type);
      final List<DocumentSnapshot> matching = perfSnap.docs.where((doc) {
        final type = (doc['type'] ?? '').toString();
        return _normalizeType(type) == normWidgetType;
      }).toList();

      if (matching.isEmpty) continue;

      final perf = matching.first.data() as Map<String, dynamic>;

      String levelOfPassage = '';
      if (perf['storyId'] != null && (perf['storyId'] as String).isNotEmpty) {
        final storySnap = await firestore.collection('Stories').doc(perf['storyId']).get();
        if (storySnap.exists && storySnap.data()?['gradeLevel'] != null) {
          levelOfPassage = storySnap.data()!['gradeLevel'].toString();
        }
      } else if (perf['quizId'] != null && (perf['quizId'] as String).isNotEmpty) {
        final quizSnap = await firestore.collection('Quizzes').doc(perf['quizId']).get();
        if (quizSnap.exists && quizSnap.data()?['gradeLevel'] != null) {
          levelOfPassage = quizSnap.data()!['gradeLevel'].toString();
        }
      }

      String dateTaken = '';
      if (perf['startTime'] != null) {
        var date = perf['startTime'];
        if (date is Timestamp) {
          dateTaken = date.toDate().toString().split(' ').first;
        } else if (date is String && date.isNotEmpty) {
          dateTaken = date.split(' ').first;
        }
      }

      String scoreMarka = '';
      if (perf['totalScore'] != null && perf['totalQuestions'] != null) {
        scoreMarka = '${perf['totalScore']} of ${perf['totalQuestions']}';
      }

      String percentScore = '';
      if (perf['totalScore'] != null && perf['totalQuestions'] != null) {
        int score = int.tryParse(perf['totalScore'].toString()) ?? 0;
        int total = int.tryParse(perf['totalQuestions'].toString()) ?? 0;
        if (total > 0) {
          percentScore = '${((score / total) * 100).round()}%';
        }
      } else if (perf['comprehensionScore'] != null) {
        try {
          double val = perf['comprehensionScore'] is int
              ? (perf['comprehensionScore'] as int).toDouble()
              : (perf['comprehensionScore'] as num).toDouble();
          percentScore = '${val.round()}%';
        } catch (e) {}
      }

      String wordReadingScore = '';
      if (perf['wordReadingScore'] != null) {
        try {
          double val = perf['wordReadingScore'] is int
              ? (perf['wordReadingScore'] as int).toDouble()
              : (perf['wordReadingScore'] as num).toDouble();
          wordReadingScore = '${val.round()}';
        } catch (e) {}
      }

      String readingRate = '';
      if (perf['readingSpeed'] != null) {
        try {
          double val = perf['readingSpeed'] is int
              ? (perf['readingSpeed'] as int).toDouble()
              : (perf['readingSpeed'] as num).toDouble();
          readingRate = '${val.round()} wpm';
        } catch (e) {}
      }

      String comprehensionScore = '';
      if (perf['comprehensionScore'] != null) {
        try {
          double val = perf['comprehensionScore'] is int
              ? (perf['comprehensionScore'] as int).toDouble()
              : (perf['comprehensionScore'] as num).toDouble();
          comprehensionScore = '${val.round()}';
        } catch (e) {}
      }

      String comprehensionLevel = '';
      if (perf['comprehensionLevel'] != null) {
        comprehensionLevel = perf['comprehensionLevel'].toString();
      }

      String wordReadingLevel = '';
      if (perf['wordReadingLevel'] != null) {
        wordReadingLevel = perf['wordReadingLevel'].toString();
      }

      String oralReadingProfile = '';
      if (perf['oralReadingProfile'] != null) {
        oralReadingProfile = perf['oralReadingProfile'].toString();
      }

      String totalMiscues = '';
      if (perf['totalMiscues'] != null) {
        totalMiscues = perf['totalMiscues'].toString();
      }

      Map<String, dynamic> row = {
        'Name': '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}',
        'Sex': student['gender'] ?? '',
        'Level of Passage': levelOfPassage,
        'Reading Time': perf['readingTime']?.toString() ?? '',
        'Total Miscues': totalMiscues,
        'Q1': '', 'Q2': '', 'Q3': '', 'Q4': '', 'Q5': '', 'Q6': '', 'Q7': '', 'Q8': '',
        'Score Marka': scoreMarka,
        '% of Score': percentScore,
        'Word Reading Score': wordReadingScore,
        'Reading Rate': readingRate,
        'Comprehension Score': comprehensionScore,
        'Word Reading Level': wordReadingLevel,
        'Comprehension Level': comprehensionLevel,
        'Oral Reading Profile': oralReadingProfile,
        'Date Taken': dateTaken,
      };

      if (perf['answers'] != null && perf['answers'] is List) {
        List<dynamic> answers = perf['answers'];
        for (int i = 0; i < 8 && i < answers.length; i++) {
          row['Q${i + 1}'] = answers[i]?.toString() ?? '';
        }
      } else if (perf['responses'] != null && perf['responses'] is List) {
        List<dynamic> responses = perf['responses'];
        for (int i = 0; i < 8 && i < responses.length; i++) {
          row['Q${i + 1}'] = responses[i]?.toString() ?? '';
        }
      }

      tableRows.add(row);
    }

    // --- SORT TABLE BY DATE TAKEN (LATEST FIRST) ---
    tableRows.sort((a, b) {
      DateTime dateA, dateB;
      try {
        dateA = DateTime.parse(a['Date Taken'] ?? '1900-01-01');
      } catch (_) {
        dateA = DateTime(1900);
      }
      try {
        dateB = DateTime.parse(b['Date Taken'] ?? '1900-01-01');
      } catch (_) {
        dateB = DateTime(1900);
      }
      return dateB.compareTo(dateA); // Descending order: latest first
    });

    return tableRows;
  } catch (e, s) {
    print('Error loading table data: $e\n$s');
    return [];
  }
}

 Future<void> _exportToCSV(List<Map<String, dynamic>> data) async {
  setState(() => _isDownloading = true);

  String typeLabel = widget.type[0].toUpperCase() + widget.type.substring(1);
  String safeTypeLabel = typeLabel.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  String fileName = 'ReadingProfile_$safeTypeLabel.csv';

  final csvBuffer = StringBuffer();
  csvBuffer.writeln(columnTitles.map((e) => '"$e"').join(','));

  for (var row in data) {
    List<String> values = columnTitles.map((col) {
      String val = row[col]?.toString() ?? '';
      if (col == 'Score Marka' || col.contains('%')) {
        val = '"${val.replaceAll('"', '""')}"';
      } else if (val.contains(',') || val.contains('"') || val.contains('/') || val.contains('%')) {
        val = '"${val.replaceAll('"', '""')}"';
      }
      return val;
    }).toList();
    csvBuffer.writeln(values.join(','));
  }


  Directory? directory;
  String? path;
  try {
    if (Platform.isAndroid) {
      // This will save in /storage/emulated/0/Download, visible to the user!
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    path = '${directory!.path}/$fileName';
    final file = File(path);
    await file.writeAsString(csvBuffer.toString(), flush: true);
  } catch (e, s) {
    setState(() => _isDownloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save CSV: $e')),
    );
    return;
  }

  setState(() => _isDownloading = false);

  // Offer to open the file directly
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("CSV Exported!"),
      content: Text("File saved to:\n$path"),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Close"),
        ),
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text("Open File"),
          onPressed: () {
            OpenFile.open(path);
            Navigator.of(ctx).pop();
          },
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _tableDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    );
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
                  String typeLabel = widget.type[0].toUpperCase() + widget.type.substring(1) + " Results";
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 0, 0, 0),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 400,
                        child: Scrollbar(
                          controller: _horizontalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: columnTitles.length * 120.0,
                              child: Scrollbar(
                                controller: _verticalController,
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller: _verticalController,
                                  itemCount: rows.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      // Table header
                                      return Container(
                                        color: const Color.fromRGBO(21, 163, 35, 0.11),
                                        child: Row(
                                          children: columnTitles
                                              .map(
                                                (title) => Container(
                                                  width: 120,
                                                  padding: const EdgeInsets.all(10),
                                                  child: AutoSizeText(
                                                    title,
                                                    maxLines: 1,
                                                    minFontSize: 9,
                                                    maxFontSize: 13,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      );
                                    } else {
                                      final row = rows[index - 1];
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: const Color(0xFF15A323).withOpacity(0.12),
                                              width: 0.6,
                                            ),
                                          ),
                                          color: Colors.white.withOpacity(0.92),
                                        ),
                                        child: Row(
                                          children: columnTitles
                                              .map(
                                                (col) => Container(
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
                                                ),
                                              )
                                              .toList(),
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
                      const SizedBox(height: 14),
                      Center(
                        child: !_permissionChecked
                          ? const CircularProgressIndicator()
                       
                            : _isDownloading
                              ? const CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF15A323),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download as CSV'),
                                  onPressed: () => _exportToCSV(rows),
                                ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
