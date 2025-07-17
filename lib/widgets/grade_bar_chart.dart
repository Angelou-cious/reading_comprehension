import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui';
import 'package:phil/utils/school_year_util.dart';


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

class GradeBarChart extends StatefulWidget {
  final bool isTeacher;
  final String teacherId;

  const GradeBarChart({
    super.key,
    required this.isTeacher,
    required this.teacherId,
  });

  @override
  State<GradeBarChart> createState() => _GradeBarChartState();
}

class _GradeBarChartState extends State<GradeBarChart> {
  final GlobalKey _pretestChartKey = GlobalKey();
  final GlobalKey _posttestChartKey = GlobalKey();
  bool isLoading = true;

  int g5PreInd = 0, g5PreInst = 0, g5PreFrus = 0;
  int g6PreInd = 0, g6PreInst = 0, g6PreFrus = 0;
  int g5PostInd = 0, g5PostInst = 0, g5PostFrus = 0;
  int g6PostInd = 0, g6PostInst = 0, g6PostFrus = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final schoolYear = await getCurrentSchoolYear();

      final students = await FirebaseFirestore.instance
          .collection('Students')
          .where('teacherId', isEqualTo: widget.teacherId)
           .where('schoolYear', isEqualTo: schoolYear)
          .get();

      if (students.docs.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      List<Future<void>> fetches = [];

      for (var student in students.docs) {
        final grade = student.data()['gradeLevel']?.toString().trim();
        final studentId = student.id;

        if (grade == "5" || grade == "6") {
          final fetchPerformance = FirebaseFirestore.instance
              .collection('StudentPerformance')
              .where('studentId', isEqualTo: studentId)
              .where('schoolYear', isEqualTo: schoolYear)
              .get()
              .then((performances) {
            for (var doc in performances.docs) {
              final type = doc['type']?.toString().toLowerCase().trim();
              final profile = doc['oralReadingProfile']?.toString().trim();

              if (type == null || profile == null) continue;

              if (type == "pretest") _inc(profile, grade!, true);
              if (type == "posttest" || type == "post test") _inc(profile, grade!, false);
            }
          });

          fetches.add(fetchPerformance);
        }
      }

      await Future.wait(fetches);
    } catch (e) {
      print("Error: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _inc(String profile, String grade, bool isPre) {
    final p = profile.toLowerCase();
    if (grade == "5") {
      if (isPre) {
        if (p == "independent") g5PreInd++;
        if (p == "instructional") g5PreInst++;
        if (p == "frustration") g5PreFrus++;
      } else {
        if (p == "independent") g5PostInd++;
        if (p == "instructional") g5PostInst++;
        if (p == "frustration") g5PostFrus++;
      }
    } else if (grade == "6") {
      if (isPre) {
        if (p == "independent") g6PreInd++;
        if (p == "instructional") g6PreInst++;
        if (p == "frustration") g6PreFrus++;
      } else {
        if (p == "independent") g6PostInd++;
        if (p == "instructional") g6PostInst++;
        if (p == "frustration") g6PostFrus++;
      }
    }
  }

  Widget buildGroupedChart({
    required String title,
    required GlobalKey chartKey,
    required List<int> grade5Counts,
    required List<int> grade6Counts,
  }) {
    final total = grade5Counts.fold(0, (a, b) => a + b) + grade6Counts.fold(0, (a, b) => a + b);
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.purple,
      Colors.yellow.shade700,
    ];

    return glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title — Total: $total',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 16),
          RepaintBoundary(
            key: chartKey,
            child: SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  maxY: [
                    ...grade5Counts,
                    ...grade6Counts,
                    grade5Counts.fold(0, (a, b) => a + b),
                    grade6Counts.fold(0, (a, b) => a + b),
                  ].reduce((a, b) => a > b ? a : b).toDouble() + 2,
                  barGroups: List.generate(2, (i) {
                    final data = i == 0 ? grade5Counts : grade6Counts;
                    final totalTested = data.fold(0, (a, b) => a + b);
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(toY: totalTested.toDouble(), width: 14, color: colors[0], borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: data[2].toDouble(), width: 14, color: colors[1], borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: data[1].toDouble(), width: 14, color: colors[2], borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: data[0].toDouble(), width: 14, color: colors[3], borderRadius: BorderRadius.circular(4)),
                      ],
                      barsSpace: 4,
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          if (value == 0) return const Text('GRADE 5');
                          if (value == 1) return const Text('GRADE 6');
                          return const SizedBox.shrink();
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, _) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  barTouchData: BarTouchData(enabled: true),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _legendDot(colors[0], 'Pupils Tested'),
              _legendDot(colors[1], 'Frustration'),
              _legendDot(colors[2], 'Instructional'),
              _legendDot(colors[3], 'Independent'),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.isTeacher)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Save as PDF"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _exportChartToPDF(chartKey, title),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Future<void> _exportChartToPDF(GlobalKey chartKey, String title) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;

      final context = chartKey.currentContext;
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
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                buildGroupedChart(
                  title: "Pretest Results",
                  chartKey: _pretestChartKey,
                  grade5Counts: [g5PreInd, g5PreInst, g5PreFrus],
                  grade6Counts: [g6PreInd, g6PreInst, g6PreFrus],
                ),
                const SizedBox(height: 10),
                buildGroupedChart(
                  title: "Posttest Results",
                  chartKey: _posttestChartKey,
                  grade5Counts: [g5PostInd, g5PostInst, g5PostFrus],
                  grade6Counts: [g6PostInd, g6PostInst, g6PostFrus],
                ),
              ],
            ),
          );
  }
}
