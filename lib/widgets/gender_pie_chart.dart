import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phil/utils/school_year_util.dart';

class GenderPieChart extends StatefulWidget {
  final String teacherId;
  const GenderPieChart({super.key, required this.teacherId});

  @override
  _GenderPieChartState createState() => _GenderPieChartState();
}

class _GenderPieChartState extends State<GenderPieChart> {
  int overallMale = 0;
  int overallFemale = 0;
  bool isLoading = true;

  Map<String, int> malePerGrade = {};
  Map<String, int> femalePerGrade = {};
  List<String> gradeLevels = [];

  @override
  void initState() {
    super.initState();
    fetchGenderCounts();
  }

  Future<void> fetchGenderCounts() async {
    try {
      final schoolYear = await getCurrentSchoolYear(); // ✅ dynamic year

      final students = await FirebaseFirestore.instance
          .collection('Students')
          .where('teacherId', isEqualTo: widget.teacherId)
          .where('schoolYear', isEqualTo: schoolYear) // ✅ filter by school year
          .get();

      for (var doc in students.docs) {
        final data = doc.data();
        final gender = data['gender']?.toString().toLowerCase();
        final grade = data['gradeLevel']?.toString();

        if (gender != null && grade != null) {
          if (!gradeLevels.contains(grade)) {
            gradeLevels.add(grade);
            malePerGrade[grade] = 0;
            femalePerGrade[grade] = 0;
          }

          if (gender == 'male') {
            overallMale++;
            malePerGrade[grade] = malePerGrade[grade]! + 1;
          } else if (gender == 'female') {
            overallFemale++;
            femalePerGrade[grade] = femalePerGrade[grade]! + 1;
          }
        }
      }

      gradeLevels.sort();
      setState(() => isLoading = false);
    } catch (e) {
      print("Error fetching gender data: $e");
      setState(() => isLoading = false);
    }
  }

  String _getPercentage(int count, int total) {
    if (total == 0) return '0';
    double percent = (count / total) * 100;
    return percent.toStringAsFixed(1);
  }

  Widget _buildPieChart({
    required String label,
    required int male,
    required int female,
    double size = 250,
    double? labelFontSize, // ✅ Optional custom font size
  }) {
    final total = male + female;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize:
                labelFontSize ??
                (size > 200 ? 20 : 14), // ✅ Use custom or fallback
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: size,
          height: size,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  color: Colors.blue,
                  value: male.toDouble(),
                  title: 'Male\n${_getPercentage(male, total)}%',
                  radius: size / 6,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: Colors.pink,
                  value: female.toDouble(),
                  title: 'Female\n${_getPercentage(female, total)}%',
                  radius: size / 6,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIndicator(Colors.blue, "Male"),
            const SizedBox(width: 10),
            _buildIndicator(Colors.pink, "Female"),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (overallMale == 0 && overallFemale == 0) {
      return const Center(child: Text("No student data available."));
    }

    // Group grade charts into rows of 2
    List<Widget> chartRows = [];
    for (int i = 0; i < gradeLevels.length; i += 2) {
      final List<Widget> rowChildren = [];

      for (int j = i; j < i + 2 && j < gradeLevels.length; j++) {
        final grade = gradeLevels[j];
        final m = malePerGrade[grade] ?? 0;
        final f = femalePerGrade[grade] ?? 0;
        rowChildren.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildPieChart(
                label: "Grade $grade",
                male: m,
                female: f,
                size: 180,
              ),
            ),
          ),
        );
      }

      chartRows.add(
        Row(mainAxisAlignment: MainAxisAlignment.center, children: rowChildren),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPieChart(
            label: "Overall Students",
            male: overallMale,
            female: overallFemale,
            size: 280,
            labelFontSize: 30,
          ),
          const SizedBox(height: 30),
          ...chartRows,
        ],
      ),
    );
  }
}
