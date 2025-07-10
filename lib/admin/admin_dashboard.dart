import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_users_page.dart';
import 'manage_content_page.dart';
import 'admin_dashboard_button.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'admin_oral_reading_chart.dart';
import 'admin_miscue_chart.dart';
import 'manage_schools_page.dart';
import 'package:reading_comprehension/main.dart';
import 'admin_reading_profile_table.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  DateTime? _lastBackPressed;
  List<String> _schoolYears = [];
  String? selectedSchoolYear;
  bool isLoading = true;

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

    years.sort((a, b) => b.compareTo(a)); // newest to oldest

    setState(() {
      _schoolYears = years;
      selectedSchoolYear = years.isNotEmpty ? years.first : null;
      isLoading = false;
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text("Logout"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MyHomePage()),
        (route) => false,
      );
    }
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to logout')),
      );
      return false;
    }
    await _logout(context);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Background(
          child: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _schoolYears.isEmpty
                    ? const Center(child: Text("No school year available"))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome, Admin!",
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text("Select School Year:", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                DropdownButton<String>(
                                  value: selectedSchoolYear,
                                  items: _schoolYears.map((year) {
                                    return DropdownMenuItem(value: year, child: Text(year));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => selectedSchoolYear = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            AdminOralReadingChart(schoolYear: selectedSchoolYear!),
                            const SizedBox(height: 24),
                            AdminMiscueChart(schoolYear: selectedSchoolYear!),
                            const SizedBox(height: 32),
                            AdminReadingProfileTable(type: "pretest", schoolYear: selectedSchoolYear!),
                            const SizedBox(height: 32),
                            AdminReadingProfileTable(type: "post test", schoolYear: selectedSchoolYear!),
                            const SizedBox(height: 32),
                            screenWidth > 600
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: const [
                                      AdminDashboardButton(
                                        title: "Manage Users",
                                        icon: Icons.group,
                                        page: ManageUsersPage(),
                                      ),
                                      AdminDashboardButton(
                                        title: "Manage Content",
                                        icon: Icons.book,
                                        page: ManageContentPage(),
                                      ),
                                      AdminDashboardButton(
                                        title: "Manage Schools",
                                        icon: Icons.school,
                                        page: ManageSchoolsPage(),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: const [
                                      AdminDashboardButton(
                                        title: "Manage Users",
                                        icon: Icons.group,
                                        page: ManageUsersPage(),
                                      ),
                                      SizedBox(height: 16),
                                      AdminDashboardButton(
                                        title: "Manage Content",
                                        icon: Icons.book,
                                        page: ManageContentPage(),
                                      ),
                                      SizedBox(height: 16),
                                      AdminDashboardButton(
                                        title: "Manage Schools",
                                        icon: Icons.school,
                                        page: ManageSchoolsPage(),
                                      ),
                                    ],
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
