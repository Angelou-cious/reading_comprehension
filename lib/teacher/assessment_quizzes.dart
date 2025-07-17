import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Screens/edit_quiz_screen.dart';
import '../widgets/background.dart';
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


class AssessmentQuizzesPage extends StatefulWidget {
  final String teacherId;

  const AssessmentQuizzesPage({super.key, required this.teacherId});

  @override
  _AssessmentQuizzesPageState createState() => _AssessmentQuizzesPageState();
}

class _AssessmentQuizzesPageState extends State<AssessmentQuizzesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Color passagesColor = Colors.white;
  Color quizzesColor = Colors.yellow;

  String? selectedSet;
  String? selectedGradeLevel;
  String sortOrder = 'Ascending'; // or 'Descending'
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
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
              labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              labelColor: Colors.yellow,
              unselectedLabelColor: Colors.white,
            ),
          ),
          body: Column(
            children: [
              _buildFilterBar(), // Unified filter bar with search
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuizListView('pretest'),
                    _buildQuizListView('custom'),
                    _buildQuizListView('post test'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            offset: Offset(0, 2),
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

  Widget _buildQuizListView(String quizType) {
  Query sharedQuery = FirebaseFirestore.instance
      .collection('Quizzes')
      .where('type', isEqualTo: quizType);

  Query teacherQuery = FirebaseFirestore.instance
      .collection('Teachers')
      .doc(widget.teacherId)
      .collection('TeacherQuizzes')
      .where('type', isEqualTo: quizType);

  if (selectedSet != null && selectedSet!.isNotEmpty) {
    sharedQuery = sharedQuery.where('set', isEqualTo: selectedSet);
    teacherQuery = teacherQuery.where('set', isEqualTo: selectedSet);
  }

  if (selectedGradeLevel != null && selectedGradeLevel!.isNotEmpty) {
    sharedQuery = sharedQuery.where('gradeLevel', isEqualTo: selectedGradeLevel);
    teacherQuery = teacherQuery.where('gradeLevel', isEqualTo: selectedGradeLevel);
  }

  var order = sortOrder == 'Ascending' ? false : true;
  sharedQuery = sharedQuery.orderBy('title', descending: order);
  teacherQuery = teacherQuery.orderBy('title', descending: order);

  return FutureBuilder(
    future: Future.wait([sharedQuery.get(), teacherQuery.get()]),
    builder: (context, AsyncSnapshot<List<QuerySnapshot>> snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      var sharedQuizzes = snapshot.data![0].docs;
      var teacherQuizzes = snapshot.data![1].docs;

      var allQuizzes = sharedQuizzes + teacherQuizzes;

      if (allQuizzes.isEmpty) {
        return const Center(child: Text('No quizzes available'));
      }

      var filteredQuizzes = allQuizzes.where((quiz) {
        var data = quiz.data() as Map<String, dynamic>;
        var title = data['title']?.toLowerCase() ?? '';
        return title.contains(searchQuery);
      }).toList();

      return ListView.builder(
        itemCount: filteredQuizzes.length,
        itemBuilder: (context, index) {
          var data = filteredQuizzes[index].data() as Map<String, dynamic>;
          var title = data['title'] ?? 'No Title';
          var gradeLevel = data['gradeLevel'] ?? 'N/A';
          var set = data['set'] ?? 'N/A';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: glassCard(
              child: ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: Text('$gradeLevel, $set'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditQuizScreen(
                        quizId: filteredQuizzes[index].id,
                        teacherId: widget.teacherId,
                      ),
                    ),
                  );
                },
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
              Text('Filter & Sort Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSet,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: ['A', 'B', 'C', 'D'].map((set) {
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: ['Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'].map((grade) {
                  return DropdownMenuItem(
                    value: grade,
                    child: Text(grade, style: TextStyle(fontSize: 14)),
                  );
                }).toList(),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                child: Text(
                  'Apply',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
}
