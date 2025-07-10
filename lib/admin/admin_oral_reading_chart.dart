import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOralReadingChart extends StatefulWidget {
  const AdminOralReadingChart({super.key, required String schoolYear});

  @override
  State<AdminOralReadingChart> createState() => _AdminOralReadingChartState();
}

class _AdminOralReadingChartState extends State<AdminOralReadingChart> {
  final GlobalKey _chartKey = GlobalKey();
  final List<String> categories = ['Independent', 'Instructional', 'Frustration'];

  List<double> pretest = [0, 0, 0];
  List<double> posttest = [0, 0, 0];
  List<String> _schoolYears = [];
  String? selectedSchoolYear;

  @override
  void initState() {
    super.initState();
    _loadSchoolYears();
  }

  Future<void> _loadSchoolYears() async {
    final snapshot = await FirebaseFirestore.instance.collection('StudentPerformance').get();
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
      await _fetchChartData();
    }
  }

  Future<void> _fetchChartData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('schoolYear', isEqualTo: selectedSchoolYear)
        .get();

    int preInd = 0, preIns = 0, preFrus = 0;
    int postInd = 0, postIns = 0, postFrus = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final profile = (data['oralReadingProfile'] ?? '').toString().toLowerCase();

      if (type == 'pretest') {
        if (profile == 'independent') preInd++;
        else if (profile == 'instructional') preIns++;
        else if (profile == 'frustration') preFrus++;
      } else if (type == 'posttest') {
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
        barsSpace: 8,
      );
    });
  }

Widget _legend(Color color, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black26),
        ),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 14)),
    ],
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
              pw.Text("Oral Reading Profile ($selectedSchoolYear)",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
  'Oral Reading Profile (All Students)',
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  ),
),
const SizedBox(height: 8),

if (_schoolYears.isNotEmpty)
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Select School Year:',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      DropdownButton<String>(
        value: selectedSchoolYear,
        items: _schoolYears.map((year) {
          return DropdownMenuItem(value: year, child: Text(year));
        }).toList(),
        onChanged: (val) async {
          if (val != null) {
            setState(() => selectedSchoolYear = val);
            await _fetchChartData();
          }
        },
      ),
    ],
  ),



            const SizedBox(height: 20),
            RepaintBoundary(
              key: _chartKey,
              child: SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    barGroups: _buildGroupedData(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (index < categories.length) {
                              return Text(categories[index], style: const TextStyle(fontSize: 11));
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, _) =>
                              Text('${value.toInt()}%', style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: true),
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
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
