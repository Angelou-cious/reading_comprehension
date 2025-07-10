import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background.dart';

// Glass card widget for reusability (as you use in other pages)
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.green.shade50, width: 1.4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: child,
    );
  }
}

class SchoolDetailPage extends StatelessWidget {
  final String schoolId;
  final String schoolName;

  const SchoolDetailPage({
    required this.schoolId,
    required this.schoolName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Background(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(schoolName, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green[700]!.withOpacity(0.92),
          foregroundColor: Colors.white,
          elevation: 3,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // --- Teachers Card ---
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.groups, color: Color(0xFF15A323)),
                            SizedBox(width: 8),
                            Text(
                              "Teachers",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Teachers')
                              .where('schoolId', isEqualTo: schoolId)
                              .orderBy('lastname', descending: false)
                              .snapshots(),
                          builder: (context, teacherSnap) {
                            if (teacherSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final teachers = teacherSnap.data?.docs ?? [];
                            if (teachers.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  children: [
                                    Icon(Icons.person_off, color: Colors.grey[400], size: 40),
                                    const SizedBox(height: 6),
                                    Text(
                                      "No teachers assigned to this school.",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: teachers.length,
                              separatorBuilder: (_, __) => const Divider(height: 8),
                              itemBuilder: (context, i) {
                                final t = teachers[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green[100],
                                    child: Icon(Icons.person, color: Colors.green[800]),
                                  ),
                                  title: Text(
                                    "${t['firstname']} ${t['lastname']}",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    "Teacher Code: ${t['teacherCode'] ?? '-'}",
                                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // --- Students Card ---
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.school, color: Color(0xFFEDC50B)),
                            SizedBox(width: 8),
                            Text(
                              "Students",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Students')
                              .where('schoolId', isEqualTo: schoolId)
                              .orderBy('lastName', descending: false)
                              .snapshots(),
                          builder: (context, studentSnap) {
                            if (studentSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final students = studentSnap.data?.docs ?? [];
                            if (students.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  children: [
                                    Icon(Icons.person_outline, color: Colors.grey[400], size: 40),
                                    const SizedBox(height: 6),
                                    Text(
                                      "No students assigned to this school.",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: students.length,
                              separatorBuilder: (_, __) => const Divider(height: 8),
                              itemBuilder: (context, i) {
                                final s = students[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.yellow[100],
                                    child: Icon(Icons.person_outline, color: Colors.orange[800]),
                                  ),
                                  title: Text(
                                    "${s['firstName']} ${s['lastName']}",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    "Grade: ${s['gradeLevel'] ?? '-'}",
                                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
