import 'package:flutter/material.dart';
import 'package:phil/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_scaffold.dart';
import 'package:phil/about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkMode = false;
  bool requireEmailVerification = true;
  bool maintenanceMode = false;
  bool isLoadingMaintenance = true;
  bool isLoadingSchoolYear = true;

  String? _activeSchoolYear;
  List<String> _availableYears = [];

  @override
  void initState() {
    super.initState();
    isDarkMode = themeNotifier.value == ThemeMode.dark;
    _loadMaintenanceMode();
    _loadSchoolYears();
  }

  Future<void> _loadMaintenanceMode() async {
    final doc = await FirebaseFirestore.instance
        .collection('AppSettings')
        .doc('global')
        .get();
    setState(() {
      maintenanceMode = doc.data()?['maintenanceMode'] ?? false;
      isLoadingMaintenance = false;
    });
  }

  Future<void> _setMaintenanceMode(bool value) async {
    setState(() => isLoadingMaintenance = true);
    await FirebaseFirestore.instance
        .collection('AppSettings')
        .doc('global')
        .set({'maintenanceMode': value}, SetOptions(merge: true));
    setState(() {
      maintenanceMode = value;
      isLoadingMaintenance = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Maintenance Mode enabled' : 'Maintenance Mode disabled',
        ),
      ),
    );
  }

  Future<void> _loadSchoolYears() async {
    setState(() => isLoadingSchoolYear = true);

    final activeDoc = await FirebaseFirestore.instance
        .collection('Settings')
        .doc('SchoolYear')
        .get();
    final yearsSnapshot = await FirebaseFirestore.instance
        .collection('Settings')
        .doc('SchoolYears')
        .collection('List')
        .get();

    setState(() {
      _activeSchoolYear = activeDoc.data()?['active'] ?? '2024-2025';
      _availableYears = yearsSnapshot.docs.map((doc) => doc.id).toList();
      isLoadingSchoolYear = false;
    });
  }

  Future<void> _updateSchoolYear(String year) async {
    await FirebaseFirestore.instance
        .collection('Settings')
        .doc('SchoolYear')
        .set({'active': year}, SetOptions(merge: true));
    setState(() => _activeSchoolYear = year);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Active school year updated to $year')),
    );
  }

  Future<void> _addSchoolYearDialog() async {
    String newYear = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add School Year'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Format: 2025-2026'),
          onChanged: (value) => newYear = value.trim(),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final validFormat = RegExp(r'^\d{4}-\d{4}$');
              if (!validFormat.hasMatch(newYear)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid format. Use YYYY-YYYY.'),
                  ),
                );
                return;
              }

              final parts = newYear.split('-');
              final start = int.tryParse(parts[0]);
              final end = int.tryParse(parts[1]);

              if (start == null || end == null || end != start + 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid range. Example: 2025-2026'),
                  ),
                );
                return;
              }

              // Find the latest school year from _availableYears
              final latestYear = _availableYears
                  .map((y) => int.tryParse(y.split('-').first) ?? 0)
                  .fold(0, (prev, curr) => curr > prev ? curr : prev);

              if (start > latestYear + 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'You can only add the next consecutive school year (max: ${latestYear + 1}-${latestYear + 2})',
                    ),
                  ),
                );
                return;
              }

              if (_availableYears.contains(newYear)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School year already exists.')),
                );
                return;
              }

              await FirebaseFirestore.instance
                  .collection('Settings')
                  .doc('SchoolYears')
                  .collection('List')
                  .doc(newYear)
                  .set({'createdAt': FieldValue.serverTimestamp()});

              setState(() => _availableYears.add(newYear));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('School year $newYear added')),
              );
            },

            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteYear(String year) async {
    if (year == _activeSchoolYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the active school year.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "$year"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('Settings')
          .doc('SchoolYears')
          .collection('List')
          .doc(year)
          .delete();

      setState(() => _availableYears.remove(year));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('School year $year deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Settings',
      showAppBar: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              'App Preferences',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15A323),
              ),
            ),
            const SizedBox(height: 15),

            _buildSettingCard(
              icon: Icons.color_lens,
              title: 'Theme Mode',
              subtitle: 'Switch between light and dark mode',
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isDarkMode', value);
                  themeNotifier.value = value
                      ? ThemeMode.dark
                      : ThemeMode.light;
                  setState(() => isDarkMode = value);
                },
                activeColor: const Color(0xFF15A323),
              ),
            ),

            _buildSettingCard(
              icon: Icons.verified_user,
              title: 'Require Email Verification',
              subtitle: 'Ensure only verified accounts can log in',
              trailing: Switch(
                value: requireEmailVerification,
                onChanged: (value) {
                  setState(() => requireEmailVerification = value);
                },
                activeColor: const Color(0xFF15A323),
              ),
            ),

            isLoadingMaintenance
                ? const Center(child: CircularProgressIndicator())
                : _buildSettingCard(
                    icon: Icons.build,
                    title: 'Maintenance Mode',
                    subtitle: 'Disable sign up and login for non-admins',
                    trailing: Switch(
                      value: maintenanceMode,
                      onChanged: (value) => _setMaintenanceMode(value),
                      activeColor: const Color(0xFF15A323),
                    ),
                  ),

            const Divider(),

            _buildSettingCard(
              icon: Icons.info_outline,
              title: 'About App',
              subtitle: 'View version, developers, and license',
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school, color: Color(0xFF15A323)),
              title: const Text(
                'School Year Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Manage active school year for data separation',
              ),
              onTap: () {},
            ),

            if (isLoadingSchoolYear)
              const Center(child: CircularProgressIndicator())
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableYears.map((year) {
                        return Chip(
                          label: Text(year),
                          backgroundColor: year == _activeSchoolYear
                              ? Colors.green[100]
                              : Colors.grey[200],
                          avatar: year == _activeSchoolYear
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          deleteIcon: year != _activeSchoolYear
                              ? const Icon(Icons.close)
                              : null,
                          onDeleted: year != _activeSchoolYear
                              ? () => _confirmDeleteYear(year)
                              : null,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Active School Year:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: DropdownButtonFormField<String>(
                            value: _activeSchoolYear,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: _availableYears.map((year) {
                              return DropdownMenuItem<String>(
                                value: year,
                                child: Text(year),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) _updateSchoolYear(value);
                            },
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addSchoolYearDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Year'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15A323),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MyHomePage()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout as Admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Icon(icon, color: const Color(0xFF15A323)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
