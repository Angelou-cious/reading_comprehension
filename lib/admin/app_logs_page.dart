import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:phil/widgets/background.dart';

class AppLogsPage extends StatefulWidget {
  const AppLogsPage({super.key});

  @override
  State<AppLogsPage> createState() => _AppLogsPageState();
}

class _AppLogsPageState extends State<AppLogsPage> {
  int studentCount = 0;
  int teacherCount = 0;
  bool isLoading = true;
  bool isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadUserCounts();
  }

  Future<void> _loadUserCounts() async {
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('Students')
          .get();
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Teachers')
          .get();

      if (!mounted) return;
      setState(() {
        studentCount = studentsSnap.docs.length;
        teacherCount = teachersSnap.docs.length;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user counts: $e');
      if (!mounted) return;
      setState(() {
        studentCount = 0;
        teacherCount = 0;
        isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final logs = await FirebaseFirestore.instance.collection('Logs').get();

    if (!mounted) return;
    setState(() => isClearing = true);

    for (var doc in logs.docs) {
      await FirebaseFirestore.instance.collection('Logs').doc(doc.id).delete();
    }

    if (!mounted) return;
    setState(() => isClearing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs cleared successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Background(
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Logs',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Pie Chart Card
                      Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: (studentCount + teacherCount == 0)
                                    ? [
                                        PieChartSectionData(
                                          value: 1,
                                          title: 'No data',
                                          color: Colors.grey,
                                          radius: 50,
                                          titleStyle: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.035,
                                          ),
                                        ),
                                      ]
                                    : [
                                        PieChartSectionData(
                                          value: studentCount.toDouble(),
                                          title: '$studentCount Students',
                                          color: Colors.blueAccent,
                                          radius: 50,
                                          titleStyle: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.02,
                                          ),
                                        ),
                                        PieChartSectionData(
                                          value: teacherCount.toDouble(),
                                          title: '$teacherCount Teachers',
                                          color: Colors.orangeAccent,
                                          radius: 50,
                                          titleStyle: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.02,
                                          ),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Actions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isClearing ? null : _clearLogs,
                            icon: const Icon(Icons.delete),
                            label: const Text('Clear Logs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Logs Stream
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Logs')
                            .orderBy('timestamp', descending: true)
                            .limit(10)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          final logs = snapshot.data!.docs;
                          if (logs.isEmpty) {
                            return const Text(
                              'No recent actions found.',
                              style: TextStyle(color: Colors.white),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final data = log.data() as Map<String, dynamic>;

                              final message = data['message'] ?? 'No message';
                              final timestamp = data['timestamp'];

                              String formattedTime = 'Invalid date';
                              if (timestamp is Timestamp) {
                                formattedTime = DateFormat(
                                  'MMM dd, yyyy – hh:mm a',
                                ).format(timestamp.toDate());
                              }

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.event_note,
                                    color: Color(0xFF15A323),
                                  ),
                                  title: Text(message),
                                  subtitle: Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
