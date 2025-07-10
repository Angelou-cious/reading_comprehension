import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.2)),
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

class MiscueBarChart extends StatefulWidget {
  final String teacherId;

  const MiscueBarChart({super.key, required this.teacherId});

  @override
  State<MiscueBarChart> createState() => _MiscueBarChartState();
}

class _MiscueBarChartState extends State<MiscueBarChart> {
  final GlobalKey _chartKey = GlobalKey();
  bool isLoading = true;

  final Map<String, int> miscueTotals = {
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

  double maxY = 5;

  @override
  void initState() {
    super.initState();
    fetchMiscueData();
  }

  Future<void> fetchMiscueData() async {
    try {
      final students = await FirebaseFirestore.instance
          .collection('Students')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      final ids = students.docs.map((e) => e.id).toList();
      for (var i = 0; i < ids.length; i += 10) {
        final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final miscues = await FirebaseFirestore.instance
            .collection('MiscueRecords')
            .where('studentId', whereIn: batch)
            .where('schoolYear', isEqualTo: await getCurrentSchoolYear())
            .get();

        for (var doc in miscues.docs) {
          final data = doc.data()['miscues'] as Map<String, dynamic>;
          data.forEach((type, value) {
            if (miscueTotals.containsKey(type)) {
              miscueTotals[type] = miscueTotals[type]! + (value as int);
            }
          });
        }
      }
      if (!mounted) return;
      setState(() {
        isLoading = false;
        maxY = miscueTotals.values.reduce((a, b) => a > b ? a : b).toDouble() + 1;
      });
    } catch (e) {
      print("Fetch error: $e");
    }
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: miscueTotals.keys.map((key) {
        final index = miscueTotals.keys.toList().indexOf(key);
        final abbr = abbreviations[key]!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, color: barColors[index]),
            const SizedBox(width: 4),
            Text('$abbr - $key', style: const TextStyle(fontSize: 13)),
          ],
        );
      }).toList(),
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final keys = miscueTotals.keys.toList();
    final index = value.toInt();
    if (index >= 0 && index < keys.length) {
      return SideTitleWidget(
        meta: meta,
        child: Text(abbreviations[keys[index]]!, style: const TextStyle(fontSize: 12)),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _exportChartToPDF() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      build: (context) => pw.Column(children: [
        pw.Text("Miscue Records (Your Students)", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),
        pw.Image(pw.MemoryImage(bytes.buffer.asUint8List())),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final keys = miscueTotals.keys.toList();
    final values = miscueTotals.values.toList();
    final total = values.reduce((a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Miscue Records (Your Students) — Total: $total",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _chartKey,
              child: SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _bottomTitle)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) =>
                              Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: List.generate(keys.length, (index) {
                      final count = values[index].toDouble();
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: count,
                            width: 16,
                            color: barColors[index],
                            borderRadius: BorderRadius.circular(4),
                            rodStackItems: [],
                            backDrawRodData: BackgroundBarChartRodData(show: false),
                          )
                        ],
                        showingTooltipIndicators: count > 0 ? [0] : [],
                        barsSpace: 4,
                      );
                    }),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: List.generate(keys.length, (index) {
                final value = values[index];
                if (value > 0) {
                  return Text(
                    "${abbreviations[keys[index]]!}: $value",
                    style: TextStyle(color: barColors[index], fontWeight: FontWeight.bold),
                  );
                }
                return const SizedBox.shrink();
              }),
            ),
            const SizedBox(height: 12),
            _buildLegend(),
            const SizedBox(height: 10),
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
