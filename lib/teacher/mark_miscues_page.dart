import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'package:reading_comprehension/utils/school_year_util.dart';


class MarkMiscuesPage extends StatefulWidget {
  final String studentId;
  final String type;
  final String performanceId; // ✅ Add this

  const MarkMiscuesPage({
    super.key, 
    required this.studentId, 
    required this.type, 
    required this.performanceId, // ✅ Ensure it's required
  });

  @override
  _MarkMiscuesPageState createState() => _MarkMiscuesPageState();
}


class _MarkMiscuesPageState extends State<MarkMiscuesPage> {
  int totalMiscueScore = 0;
  String selectedType = "pretest"; // ✅ Local variable for managing type
  bool isLoading = true; // ✅ Add an isLoading flag
  bool _isSaving = false;

  Map<String, int> miscues = {
    'Mispronunciation': 0,
    'Omission': 0,
    'Substitution': 0,
    'Insertion': 0,
    'Repetition': 0,
    'Transposition': 0,
    'Reversal': 0,
  };

  @override
  void initState() {
    super.initState();
    _determineMiscueType(); // Automatically selects Pretest or Posttest based on student progress
  }

  /// ✅ Determines whether the student should be marked for Pretest or Posttest
Future<void> _determineMiscueType() async {
  try {
    final performanceDoc = await FirebaseFirestore.instance
        .collection('StudentPerformance')
        .doc(widget.performanceId) // ✅ Use passed ID directly
        .get();

    if (!performanceDoc.exists) {
      debugPrint("❌ Error: No StudentPerformance record found for ID ${widget.performanceId}");
      return;
    }

    var performanceData = performanceDoc.data();
    if (performanceData == null) {
      debugPrint("❌ Error: Performance data is null");
      return;
    }

    String latestTestType = performanceData['type']?.toString().toLowerCase() ?? "pretest";

    setState(() {
      selectedType = latestTestType;
    });

    debugPrint('✅ Marking Miscues for Type: $selectedType');

    await _loadMiscueRecords();
  } catch (e) {
    debugPrint('❌ Error determining miscue type: $e');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}



  /// ✅ Fetch miscue records for the selected test type
  Future<void> _loadMiscueRecords() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('MiscueRecords')
          .where('studentId', isEqualTo: widget.studentId)
          .where('type', isEqualTo: selectedType)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final miscuesData = querySnapshot.docs.first.data();
        setState(() {
          miscues = Map<String, int>.from(miscuesData['miscues']);
          totalMiscueScore = miscuesData['totalMiscueScore'] ?? 0;
        });
      } else {
        debugPrint('No previous miscues found for $selectedType');
      }
    } catch (e) {
      debugPrint('❌ Error loading miscues: $e');
    }
  }

  /// ✅ Increment Miscue Count
  void _incrementMiscueScore(String miscueType) {
    setState(() {
      miscues[miscueType] = (miscues[miscueType] ?? 0) + 1;
      totalMiscueScore++;
    });
  }

  /// ✅ Decrement Miscue Count
  void _decrementMiscueScore(String miscueType) {
    setState(() {
      if (miscues[miscueType]! > 0) {
        miscues[miscueType] = miscues[miscueType]! - 1;
        totalMiscueScore--;
      }
    });
  }

  /// ✅ Save Miscue Score to Firestore
 Future<void> _saveMiscueScore() async {
  if (_isSaving) return; // ✅ Prevent multiple taps
  setState(() {
    _isSaving = true; // ✅ Show processing indicator
  });

  try {
    debugPrint('Saving Miscues for Type: $selectedType');

    // ✅ Show a processing message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Processing... Please wait'),
        duration: Duration(seconds: 2), // Show for 2 seconds
      ),
    );

    final querySnapshot = await FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('studentId', isEqualTo: widget.studentId)
        .where('type', isEqualTo: selectedType)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No performance record found.')),
      );
      debugPrint('⚠️ No performance record found for studentId: ${widget.studentId}, type: $selectedType');
      setState(() => _isSaving = false);
      return;
    }

    final performanceDoc = querySnapshot.docs.first;
    final performanceData = performanceDoc.data();
    final performanceId = performanceDoc.id;
    final schoolYear = await getCurrentSchoolYear();


    int passageWordCount = performanceData['passageWordCount'] ?? 0;
    double wordReadingScore = ((passageWordCount - totalMiscueScore) / passageWordCount) * 100;

    // ✅ Save to Firestore
    await FirebaseFirestore.instance.collection('MiscueRecords').add({
      'studentId': widget.studentId,
      'type': selectedType,
      'performanceId': performanceId,
      'miscues': miscues,
      'totalMiscueScore': totalMiscueScore,
      'timestamp': Timestamp.now(),
      'schoolYear': schoolYear, 
    });

    // ✅ If pretest is completed, mark it in Firestore
    if (selectedType == "pretest") {
      await FirebaseFirestore.instance
          .collection('StudentPerformance')
          .doc(performanceId)
          .update({'pretestCompleted': true});

      debugPrint('✅ Pretest completed. Switching to post-test...');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Miscue record saved successfully!')),
    );

    // ✅ Navigate back to the student list
    Navigator.pop(context);

  } catch (e) {
    debugPrint('❌ Error saving miscues: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving record: $e')),
    );
  } finally {
    setState(() => _isSaving = false);
  }
}



  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(), // Show loading indicator while isLoading is true
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Score Miscues - $selectedType'),
        backgroundColor: const Color(0xFF15A323),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Background(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    Text(
                      'Total Miscue Score: $totalMiscueScore',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...miscues.keys.map((miscueType) => _buildMiscueRow(miscueType)).toList(),
                  ],
                ),
              ),
            ),
          ),
          if (_isSaving)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
floatingActionButton: ElevatedButton.icon(
  onPressed: _isSaving ? null : _saveMiscueScore, // ✅ Disable button while saving
  icon: _isSaving 
      ? const CircularProgressIndicator(color: Colors.white) 
      : const Icon(Icons.save, color: Colors.white), // ✅ Show loading icon
  label: Text(
    _isSaving ? 'Processing...' : 'Save Miscues',
    style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF15A323),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25),
    ),
  ),
),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMiscueRow(String miscueType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(miscueType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => _decrementMiscueScore(miscueType)),
                  Text('${miscues[miscueType]}'),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => _incrementMiscueScore(miscueType)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
