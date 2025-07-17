import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminOralReadingChart extends StatefulWidget {
  final String schoolYear;
  const AdminOralReadingChart({super.key, required this.schoolYear});

  @override
  State<AdminOralReadingChart> createState() => _AdminOralReadingChartState();
}

class _AdminOralReadingChartState extends State<AdminOralReadingChart> {
  final GlobalKey _chartKey = GlobalKey();
  final List<String> categories = ['Independent', 'Instructional', 'Frustration'];

  List<double> pretest = [0, 0, 0];
  List<double> posttest = [0, 0, 0];

  String? selectedTeacherId = 'All';
  String selectedGrade = 'All';
  String selectedGender = 'All';

  List<Map<String, dynamic>> teachers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeachers().then((_) => _fetchChartData());
  }

  @override
  void didUpdateWidget(covariant AdminOralReadingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolYear != widget.schoolYear) {
      _fetchChartData();
    }
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await FirebaseFirestore.instance.collection('Teachers').get();
    setState(() {
      teachers = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': "${data['firstname'] ?? ''} ${data['lastname'] ?? ''}".trim(),
        };
      }).toList();
    });
  }

  Future<void> _fetchChartData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('schoolYear', isEqualTo: widget.schoolYear)
        .get();

    int preInd = 0, preIns = 0, preFrus = 0;
    int postInd = 0, postIns = 0, postFrus = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final profile = (data['oralReadingProfile'] ?? '').toString().toLowerCase();
      final studentId = data['studentId'] ?? '';

      if (studentId == '') continue;

      final studentSnapshot = await FirebaseFirestore.instance.collection('Students').doc(studentId).get();
      if (!studentSnapshot.exists) continue;

      final student = studentSnapshot.data()!;
      final teacherId = student['teacherId'] ?? '';
      final grade = student['gradeLevel']?.toString() ?? '';
      final gender = (student['gender'] ?? '').toString().toLowerCase();

      if (selectedTeacherId != 'All' && selectedTeacherId != teacherId) continue;
      if (selectedGrade != 'All' && grade != selectedGrade.replaceAll('Grade ', '')) continue;
      if (selectedGender != 'All' && gender != selectedGender.toLowerCase()) continue;

      if (type == 'pretest') {
        if (profile == 'independent') preInd++;
        else if (profile == 'instructional') preIns++;
        else if (profile == 'frustration') preFrus++;
      } else if (type == 'post test') {
        if (profile == 'independent') postInd++;
        else if (profile == 'instructional') postIns++;
        else if (profile == 'frustration') postFrus++;
      }
    }

    final preTotal = preInd + preIns + preFrus;
    final postTotal = postInd + postIns + postFrus;

    setState(() {
      pretest = preTotal > 0 ? [preInd / preTotal * 100, preIns / preTotal * 100, preFrus / preTotal * 100] : [0, 0, 0];
      posttest = postTotal > 0 ? [postInd / postTotal * 100, postIns / postTotal * 100, postFrus / postTotal * 100] : [0, 0, 0];
    });
  }

  List<BarChartGroupData> _buildGroupedData() {
    return List.generate(categories.length, (i) {
      return BarChartGroupData(
        x: i,
        barsSpace: 8,
        barRods: [
          BarChartRodData(
            toY: pretest[i],
            color: Colors.amber,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: posttest[i],
            color: const Color(0xFF15A323),
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  Future<void> _exportChartToPDF() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;

      final context = _chartKey.currentContext;
      if (context == null) return;

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text("Oral Reading Profile (${widget.schoolYear})", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Image(pw.MemoryImage(pngBytes)),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print("PDF Export Error: $e");
    }
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black26))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE9FBEF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF15A323), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Oral Reading Profile (Filtered) - SY ${widget.schoolYear}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Teacher Dropdown
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Teacher'),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All')),
                        ...teachers.map((teacher) {
                          return DropdownMenuItem(
                            value: teacher['id'],
                            child: Text(teacher['name']),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => selectedTeacherId = value ?? 'All');
                        _fetchChartData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Grade Dropdown
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      value: selectedGrade,
                      decoration: const InputDecoration(labelText: 'Grade'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Grade 5', child: Text('Grade 5')),
                        DropdownMenuItem(value: 'Grade 6', child: Text('Grade 6')),
                      ],
                      onChanged: (value) {
                        setState(() => selectedGrade = value ?? 'All');
                        _fetchChartData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Gender Dropdown
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (value) {
                        setState(() => selectedGender = value ?? 'All');
                        _fetchChartData();
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            RepaintBoundary(
              key: _chartKey,
              child: SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    barGroups: _buildGroupedData(),
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          return Text(index < categories.length ? categories[index] : '', style: const TextStyle(fontSize: 11));
                        }),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10))),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: true),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend(Colors.amber, "Pretest"),
                const SizedBox(width: 24),
                _legend(const Color(0xFF15A323), "Posttest"),
              ],
            ),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Save as PDF"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _exportChartToPDF,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
