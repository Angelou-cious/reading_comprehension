import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:phil/widgets/background.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  String searchQuery = '';
  String roleFilter = 'all';
  List<Map<String, dynamic>> users = [];
  Set<String> selectedUserIds = {};
  bool isLoading = false;

  List<String> schoolYears = [];
  String? selectedSchoolYear;

  @override
  void initState() {
    super.initState();
    _loadSchoolYears();
  }

  Future<void> _loadSchoolYears() async {
    final firestore = FirebaseFirestore.instance;
    final activeSnapshot = await firestore
        .collection('Settings')
        .doc('SchoolYear')
        .get();
    final activeYear = activeSnapshot.data()?['active'];

    final snapshot = await firestore.collection('StudentPerformance').get();
    final years = snapshot.docs
        .map((doc) => doc.data())
        .where((data) => data.containsKey('schoolYear'))
        .map((data) => data['schoolYear'].toString())
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a));

    setState(() {
      schoolYears = years;
      selectedSchoolYear =
          activeYear ?? (years.isNotEmpty ? years.first : null);
    });

    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final firestore = FirebaseFirestore.instance;
    List<Map<String, dynamic>> results = [];

    try {
      final usersSnap = await firestore.collection('Users').get();
      for (var doc in usersSnap.docs) {
        final role = doc['role'];
        final userId = doc.id;
        final email = doc['email'];

        if (role == 'teacher') {
          final teacherDoc = await firestore
              .collection('Teachers')
              .doc(userId)
              .get();
          final teacherData = teacherDoc.data();
          final firstName = teacherData?['firstname'] ?? '';
          final lastName = teacherData?['lastname'] ?? '';
          final lastReset = teacherData?['resetAt'];

          results.add({
            'id': userId,
            'email': email,
            'role': role,
            'firstName': firstName,
            'lastName': lastName,
            'lastReset': lastReset,
          });
        }
      }

      final studentsSnap = await firestore.collection('Students').get();
      for (var doc in studentsSnap.docs) {
        final data = doc.data();
        final year = data['schoolYear'];
        if (year != selectedSchoolYear) continue;

        final teacherId = data['teacherId'];
        String teacherName = '';
        if (teacherId != null) {
          final teacherDoc = await firestore
              .collection('Teachers')
              .doc(teacherId)
              .get();
          if (teacherDoc.exists) {
            final tData = teacherDoc.data();
            teacherName =
                '${tData?['firstname'] ?? ''} ${tData?['lastname'] ?? ''}'
                    .trim();
          }
        }

        results.add({
          'id': doc.id,
          'email': data['email'],
          'role': 'student',
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'lastReset': data['lastReset'],
          'teacherId': teacherId,
          'teacherName': teacherName,
        });
      }

      results.sort((a, b) {
        final aName = '${a['firstName']} ${a['lastName']}'.toLowerCase();
        final bName = '${b['firstName']} ${b['lastName']}'.toLowerCase();
        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        users = results;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
    }
  }

  Future<void> _resetUserData(String userId, String role) async {
    final firestore = FirebaseFirestore.instance;

    if (role == 'teacher') {
      await firestore.collection('Teachers').doc(userId).update({
        'assignedClass': [],
        'resetAt': Timestamp.now(),
      });

      final students = await firestore
          .collection('Students')
          .where('teacherId', isEqualTo: userId)
          .get();
      for (var doc in students.docs) {
        await doc.reference.update({'teacherId': null});
      }
    } else if (role == 'student') {
      final docRef = firestore.collection('Students').doc(userId);
      final subcollections = [
        'AssignedAssessments',
        'StudentPerformance',
        'MiscueRecords',
      ];

      for (String sub in subcollections) {
        final subSnap = await docRef.collection(sub).get();
        for (var doc in subSnap.docs) {
          await doc.reference.delete();
        }
      }

      await docRef.update({
        'completedLessons': [],
        'lastReset': Timestamp.now(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = users.where((user) {
      final email = (user['email'] ?? '').toString().toLowerCase();
      final firstName = (user['firstName'] ?? '').toString().toLowerCase();
      final lastName = (user['lastName'] ?? '').toString().toLowerCase();
      final fullName = '$firstName $lastName';
      final role = user['role'];
      return (email.contains(searchQuery) ||
              firstName.contains(searchQuery) ||
              lastName.contains(searchQuery) ||
              fullName.contains(searchQuery)) &&
          (roleFilter == 'all' || role == roleFilter);
    }).toList();

    final studentFilteredIds = filtered
        .where((u) => u['role'] == 'student')
        .map((u) => u['id'] as String)
        .toList();
    final teacherFilteredIds = filtered
        .where((u) => u['role'] == 'teacher')
        .map((u) => u['id'] as String)
        .toList();

    return Scaffold(
      body: Background(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Users',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search by email or name",
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          if (!mounted) return;
                          setState(
                            () => searchQuery = value.trim().toLowerCase(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: roleFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text("All")),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text("Teachers"),
                        ),
                        DropdownMenuItem(
                          value: 'student',
                          child: Text("Students"),
                        ),
                      ],
                      onChanged: (value) {
                        if (!mounted) return;
                        setState(() => roleFilter = value!);
                      },
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedSchoolYear,
                      hint: const Text("School Year"),
                      items: schoolYears
                          .map(
                            (year) => DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            ),
                          )
                          .toList(),
                      onChanged: (year) {
                        if (!mounted) return;
                        setState(() {
                          selectedSchoolYear = year;
                          _loadUsers();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.any((u) => u['role'] == 'student'))
                  CheckboxListTile(
                    title: const Text("Select All Students"),
                    value:
                        selectedUserIds.containsAll(studentFilteredIds) &&
                        studentFilteredIds.isNotEmpty,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedUserIds.addAll(studentFilteredIds);
                        } else {
                          selectedUserIds.removeAll(studentFilteredIds);
                        }
                      });
                    },
                  ),
                if (filtered.any((u) => u['role'] == 'teacher'))
                  CheckboxListTile(
                    title: const Text("Select All Teachers"),
                    value:
                        selectedUserIds.containsAll(teacherFilteredIds) &&
                        teacherFilteredIds.isNotEmpty,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedUserIds.addAll(teacherFilteredIds);
                        } else {
                          selectedUserIds.removeAll(teacherFilteredIds);
                        }
                      });
                    },
                  ),
                if (selectedUserIds.any(
                      (id) => users.any(
                        (u) => u['id'] == id && u['role'] == 'student',
                      ),
                    ) &&
                    !selectedUserIds.any(
                      (id) => users.any(
                        (u) => u['id'] == id && u['role'] == 'teacher',
                      ),
                    ))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      "Reassign Selected Students (${selectedUserIds.length})",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () async {
                      String? selectedTeacherId;
                      final teachers = users
                          .where((u) => u['role'] == 'teacher')
                          .toList();

                      final teacherId = await showDialog<String>(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setState) => AlertDialog(
                            title: const Text("Select Teacher"),
                            content: teachers.isEmpty
                                ? const Text(
                                    "No available teachers. Please add a teacher first.",
                                  )
                                : DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Text(
                                      "Choose teacher to reassign",
                                    ),
                                    value: selectedTeacherId,
                                    items: teachers
                                        .map(
                                          (teacher) => DropdownMenuItem<String>(
                                            value: teacher['id'],
                                            child: Text(
                                              '${teacher['firstName']} ${teacher['lastName']}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => selectedTeacherId = value,
                                    ),
                                  ),

                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, selectedTeacherId),
                                child: const Text("Assign"),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (teacherId != null && selectedSchoolYear != null) {
                        final firestore = FirebaseFirestore.instance;
                        for (final studentId in selectedUserIds) {
                          final user = users.firstWhere(
                            (u) => u['id'] == studentId,
                          );
                          if (user['role'] == 'student') {
                            await firestore
                                .collection('Students')
                                .doc(studentId)
                                .update({
                                  'teacherId': teacherId,
                                  'schoolYear': selectedSchoolYear,
                                  'gradeLevel':
                                      'Grade 6', // optional: update dynamically
                                });
                          }
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Students reassigned successfully"),
                          ),
                        );
                        if (!mounted) return;
                        setState(() => selectedUserIds.clear());
                        await _loadUsers();
                      }
                    },
                  ),
                const SizedBox(height: 10),
                if (selectedUserIds.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text("Reset Selected (${selectedUserIds.length})"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Reset'),
                          content: const Text(
                            'Are you sure you want to reset the selected user(s)? This will clear all related data.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        for (final id in selectedUserIds) {
                          final user = users.firstWhere((u) => u['id'] == id);
                          await _resetUserData(id, user['role']);
                        }
                        if (!mounted) return;
                        setState(() => selectedUserIds.clear());
                        await _loadUsers();
                      }
                    },
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? const Center(child: Text("No users found"))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            final email = user['email'];
                            final role = user['role'];
                            final id = user['id'];
                            final isSelected = selectedUserIds.contains(id);
                            final lastReset = user['lastReset'];
                            final resetText = (lastReset is Timestamp)
                                ? "Last Reset: ${DateFormat.yMMMd().add_jm().format(lastReset.toDate())}"
                                : "No Reset Record";

                            return Card(
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    if (!mounted) return;
                                    setState(() {
                                      if (isSelected) {
                                        selectedUserIds.remove(id);
                                      } else {
                                        selectedUserIds.add(id);
                                      }
                                    });
                                  },
                                ),
                                title: Text(
                                  '${user['firstName']} ${user['lastName']}',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Email: $email"),
                                    Text("Role: $role"),
                                    if (role == 'student')
                                      Text(
                                        "Teacher in Charge: ${user['teacherName']?.toString().isNotEmpty == true ? user['teacherName'] : 'None'}",
                                      ),
                                    Text(resetText),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
