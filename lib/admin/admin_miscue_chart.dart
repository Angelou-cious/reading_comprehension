import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminMiscueChart extends StatefulWidget {
  final String schoolYear;
  const AdminMiscueChart({super.key, required this.schoolYear});

  @override
  State<AdminMiscueChart> createState() => _AdminMiscueChartState();
}

class _AdminMiscueChartState extends State<AdminMiscueChart> {
  final GlobalKey _chartKey = GlobalKey();
  bool isLoading = true;

  final Map<String, int> miscueCounts = {
    'Insertion': 0,
    'Mispronunciation': 0,
    'Omission': 0,
    'Repetition': 0,
    'Reversal': 0,
    'Substitution': 0,
    'Transposition': 0,
  };

  final Map<String, String> abbreviations = {
    'Insertion': 'I',
    'Mispronunciation': 'M',
    'Omission': 'O',
    'Repetition': 'R',
    'Reversal': 'V',
    'Substitution': 'S',
    'Transposition': 'T',
  };

  final List<Color> barColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.green,
    Colors.orangeAccent,
    Colors.purple,
    Colors.teal,
    Colors.pinkAccent,
  ];

  String? selectedTeacherId = 'All';
  String selectedGrade = 'All';
  String selectedGender = 'All';
  List<Map<String, dynamic>> teachers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeachers().then((_) => fetchData());
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await FirebaseFirestore.instance.collection('Teachers').get();
    setState(() {
      teachers = snapshot.docs.map((e) {
        final data = e.data();
        return {
          'id': e.id,
          'name': "${data['firstname'] ?? ''} ${data['lastname'] ?? ''}".trim(),
        };
      }).toList();
    });
  }

  @override
  void didUpdateWidget(covariant AdminMiscueChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schoolYear != oldWidget.schoolYear) {
      fetchData();
    }
  }

  @override
  void dispose() {
    miscueCounts.updateAll((key, value) => 0); // Clear counts
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      setState(() {
        isLoading = true;
        for (var key in miscueCounts.keys) {
          miscueCounts[key] = 0;
        }
      });

      final miscuesSnapshot = await FirebaseFirestore.instance
          .collection('MiscueRecords')
          .where('schoolYear', isEqualTo: widget.schoolYear)
          .get();

      for (var doc in miscuesSnapshot.docs) {
        final data = doc.data();
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

        final miscues = data['miscues'] as Map<String, dynamic>?;
        if (miscues != null) {
          for (var key in miscueCounts.keys) {
            final rawValue = miscues[key];
            if (rawValue != null) {
              miscueCounts[key] = miscueCounts[key]! + (rawValue is int ? rawValue : (rawValue as num).toInt());
            }
          }
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("Error fetching miscue data: $e");
      setState(() => isLoading = false);
    }
  }

  Widget _buildLegend() {
    final keys = miscueCounts.keys.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(keys.length, (index) {
        final label = keys[index];
        final abbr = abbreviations[label]!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: barColors[index]),
            const SizedBox(width: 4),
            Text('$abbr - $label', style: const TextStyle(fontSize: 8)),
          ],
        );
      }),
    );
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
              pw.Text("Total Miscue Records (${widget.schoolYear})", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final keys = miscueCounts.keys.toList();
    final values = miscueCounts.values.toList();
    final maxY = (values.reduce((a, b) => a > b ? a : b).toDouble()) + 2;
    final total = values.reduce((a, b) => a + b);

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
            Text(
              "Total Miscue Records ($total) — ${widget.schoolYear}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),

            // Filtering Dropdowns
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Teacher Filter
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
                        setState(() => selectedTeacherId = value);
                        fetchData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Grade Filter
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
                        setState(() => selectedGrade = value!);
                        fetchData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Gender Filter
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
                        setState(() => selectedGender = value!);
                        fetchData();
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
                height: 300,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(abbreviations[keys[index]]!, style: const TextStyle(fontSize: 12)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(keys.length, (index) {
                      final y = values[index].toDouble();
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: y,
                            color: barColors[index],
                            width: 16,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
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
