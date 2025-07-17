import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phil/teacher/story_detail_page.dart';
import 'package:phil/widgets/background.dart';
import 'package:phil/screens/create_story_page.dart';
import 'package:phil/widgets/assign_story_quiz_page.dart';
import 'dart:ui';

Widget glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
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

class AssessmentPage extends StatefulWidget {
  final String teacherId;

  const AssessmentPage({super.key, required this.teacherId});

  @override
  _AssessmentPageState createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Color passagesColor = Colors.yellow;
  Color quizzesColor = Colors.white;

  String? selectedSet;
  String? selectedGradeLevel;
  String sortOrder = 'Ascending';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);

    // Log the teacherId being passed to this page
    log('Passed teacherId: ${widget.teacherId}');

    // Log the UID of the currently authenticated user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      log('Authenticated user UID: ${currentUser.uid}');
    } else {
      log('No user is currently authenticated');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Background(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF15A323),
            elevation: 0,

            title: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Pretest'),
                Tab(text: 'Custom'),
                Tab(text: 'Posttest'),
              ],
              indicatorColor: Colors.yellow,
              labelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              labelColor: Colors.yellow,
              unselectedLabelColor: Colors.white,
            ),
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStoryListView('pretest'),
                    _buildStoryListView('custom'),
                    _buildStoryListView('post test'),
                  ],
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationTab({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 2,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white,
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2), // Shadow position
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by title',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          IconButton(
            tooltip: 'Filter & Sort',
            icon: Icon(Icons.filter_list, color: Colors.green),
            onPressed: () => _showFilterOptions(context),
          ),
          IconButton(
            tooltip: 'Clear Filters',
            icon: Icon(Icons.restart_alt_sharp, color: Colors.redAccent),
            onPressed: _clearFilters,
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      selectedSet = null;
      selectedGradeLevel = null;
      sortOrder = 'Ascending';
      searchQuery = '';
    });
  }

  Widget _buildStoryListView(String testType) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != widget.teacherId) {
      log(
        'Unauthorized: currentUser=${currentUser?.uid}, teacherId=${widget.teacherId}',
      );
      return const Center(child: Text("Permission Denied: Unauthorized User"));
    }

    Query sharedQuery = FirebaseFirestore.instance
        .collection('Stories')
        .where('type', isEqualTo: testType);

    Query teacherQuery = FirebaseFirestore.instance
        .collection('Teachers')
        .doc(widget.teacherId)
        .collection('TeacherStories')
        .where('type', isEqualTo: testType);

    if (selectedSet != null && selectedSet!.isNotEmpty) {
      sharedQuery = sharedQuery.where('set', isEqualTo: selectedSet);
      teacherQuery = teacherQuery.where('set', isEqualTo: selectedSet);
    }

    if (selectedGradeLevel != null && selectedGradeLevel!.isNotEmpty) {
      sharedQuery = sharedQuery.where(
        'gradeLevel',
        isEqualTo: selectedGradeLevel,
      );
      teacherQuery = teacherQuery.where(
        'gradeLevel',
        isEqualTo: selectedGradeLevel,
      );
    }

    final bool descending = sortOrder == 'Descending';
    sharedQuery = sharedQuery.orderBy('title', descending: descending);
    teacherQuery = teacherQuery.orderBy('title', descending: descending);

    return FutureBuilder(
      future: Future.wait([sharedQuery.get(), teacherQuery.get()]),
      builder: (context, AsyncSnapshot<List<QuerySnapshot>> snapshot) {
        if (snapshot.hasError) {
          log('Error retrieving stories: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sharedStories = snapshot.data![0].docs;
        final teacherStories = snapshot.data![1].docs;
        final allStories = sharedStories + teacherStories;

        if (allStories.isEmpty) {
          return const Center(child: Text('No data found'));
        }

        final filteredStories = allStories.where((story) {
          final data = story.data() as Map<String, dynamic>;
          final title = data['title']?.toLowerCase() ?? '';
          return title.contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: filteredStories.length,
          itemBuilder: (context, index) {
            final data = filteredStories[index].data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled';
            final gradeLevel = data['gradeLevel'] ?? 'N/A';
            final set = data['set'] ?? 'N/A';
            final isTeacher = teacherStories.contains(filteredStories[index]);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: glassCard(
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text('$gradeLevel, $set'),
                  onTap: () => _navigateToStoryDetail(
                    filteredStories[index].id,
                    title,
                    data['content'] ?? '',
                    isTeacher,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Filter & Sort Options',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSet,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                items: ['Set A', 'Set B', 'Set C', 'Set D'].map((set) {
                  return DropdownMenuItem(
                    value: set,
                    child: Text(set, style: TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSet = value;
                  });
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGradeLevel,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                items: ['Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6']
                    .map((grade) {
                      return DropdownMenuItem(
                        value: grade,
                        child: Text(grade, style: TextStyle(fontSize: 14)),
                      );
                    })
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGradeLevel = value;
                  });
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: sortOrder,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.sort),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                items: ['Ascending', 'Descending'].map((order) {
                  return DropdownMenuItem(
                    value: order,
                    child: Text(order, style: TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    sortOrder = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Apply', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateStoryPage(teacherId: widget.teacherId),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                'Add Passage',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AssignStoryQuizPage(teacherId: widget.teacherId),
                  ),
                );
              },
              icon: const Icon(Icons.assignment, color: Colors.black),
              label: const Text(
                'Assign Passage',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToStoryDetail(
    String docId,
    String title,
    String content,
    bool isTeacherStory,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryDetailPage(
          docId: docId,
          title: title,
          content: content,
          isTeacherStory: isTeacherStory,
          teacherId: isTeacherStory ? widget.teacherId : null,
        ),
      ),
    );
  }
}
