import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminMiscueChart extends StatefulWidget {
  const AdminMiscueChart({super.key, required String schoolYear});

  @override
  State<AdminMiscueChart> createState() => _AdminMiscueChartState();
}

class _AdminMiscueChartState extends State<AdminMiscueChart> {
  final GlobalKey _chartKey = GlobalKey();
  bool isLoading = true;
  List<String> _schoolYears = [];
  String? selectedSchoolYear;

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

  @override
  void initState() {
    super.initState();
    _loadSchoolYears();
  }

  Future<void> _loadSchoolYears() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('MiscueRecords').get();
      final years = snapshot.docs
          .map((doc) => doc.data())
          .where((data) => data.containsKey('schoolYear') && data['schoolYear'].toString().trim().isNotEmpty)
          .map((data) => data['schoolYear'].toString())
          .toSet()
          .toList();

      years.sort((a, b) => b.compareTo(a));

      setState(() {
        _schoolYears = years;
        selectedSchoolYear = _schoolYears.isNotEmpty ? _schoolYears.first : null;
      });

      if (selectedSchoolYear != null) {
        await fetchData();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error loading school years: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchData() async {
    try {
      setState(() {
        isLoading = true;
        for (var key in miscueCounts.keys) {
          miscueCounts[key] = 0;
        }
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('MiscueRecords')
          .where('schoolYear', isEqualTo: selectedSchoolYear)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final miscues = data['miscues'] as Map<String, dynamic>?;

        if (miscues != null) {
          for (var key in miscueCounts.keys) {
            miscueCounts[key] = miscueCounts[key]! + (miscues[key] ?? 0) as int;
          }
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => isLoading = false);
    }
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
              pw.Text("Total Miscue Records ($selectedSchoolYear)", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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

  Widget _buildLegend() {
    final keys = miscueCounts.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(keys.length, (index) {
          final label = keys[index];
          final abbr = abbreviations[label]!;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Container(width: 14, height: 14, color: barColors[index]),
                const SizedBox(width: 6),
                Text('$abbr - $label', style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (_schoolYears.isEmpty || selectedSchoolYear == null) {
      return const Center(
        child: Text(
          "No data available. No school year records found.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    final keys = miscueCounts.keys.toList();
    final values = miscueCounts.values.toList();
    final maxY = values.reduce((a, b) => a > b ? a : b).toDouble() + 2;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Miscue Records — Total: $total",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                DropdownButton<String>(
                  value: selectedSchoolYear,
                  items: _schoolYears.map((year) {
                    return DropdownMenuItem(value: year, child: Text(year));
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => selectedSchoolYear = val);
                      await fetchData();
                    }
                  },
                ),
              ],
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
