import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:phil/widgets/background.dart';
import 'package:phil/admin/school_detail_page.dart';

class ManageSchoolsPage extends StatefulWidget {
  const ManageSchoolsPage({super.key});

  @override
  State<ManageSchoolsPage> createState() => _ManageSchoolsPageState();
}

class _ManageSchoolsPageState extends State<ManageSchoolsPage> {
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _addSchool() async {
    final name = _schoolController.text.trim();
    if (name.isEmpty) return;
    await FirebaseFirestore.instance.collection('Schools').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _schoolController.clear();
  }

  Future<void> _deleteSchool(String docId) async {
    await FirebaseFirestore.instance.collection('Schools').doc(docId).delete();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'No date';
    return DateFormat('yyyy-MM-dd').format(timestamp.toDate());
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Background(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Manage Schools'),
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.85),
          foregroundColor: Colors.green[900],
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // --- Add School ---
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _schoolController,
                        decoration: InputDecoration(
                          labelText: "Add School Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _addSchool(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _addSchool,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          "Add",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15A323),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // --- Search Bar ---
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                    hintText: "Search School...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Schools')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final schools = snapshot.data?.docs ?? [];
                      // Filter schools using the search query
                      final filteredSchools = schools.where((doc) {
                        final name = (doc['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery);
                      }).toList();
                      if (filteredSchools.isEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school,
                              color: Colors.grey[400],
                              size: 72,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "No schools found.",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: filteredSchools.length,
                        itemBuilder: (context, index) {
                          final doc = filteredSchools[index];
                          final name = doc['name'] ?? '';
                          final createdAt = doc['createdAt'] as Timestamp?;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SchoolDetailPage(
                                    schoolId: doc.id,
                                    schoolName: name,
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                leading: Icon(
                                  Icons.school,
                                  color: Color(0xFF15A323),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                  ),
                                ),
                                subtitle: Text(
                                  createdAt != null
                                      ? "Date Created: ${_formatDate(createdAt)}"
                                      : "Date Created: Not set",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),

                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Confirm Deletion'),
                                        content: Text(
                                          'Are you sure you want to delete "$name"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await _deleteSchool(doc.id);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '"$name" has been deleted.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
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
