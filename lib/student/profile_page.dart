import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phil/widgets/background.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:phil/Screens/splash_screen.dart';

class ProfilePage extends StatefulWidget {
  final String studentId;

  const ProfilePage({super.key, required this.studentId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // State variables
  String firstName = '';
  String lastName = '';
  String profilePictureUrl = '';
  String gender = '';
  String grade = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  // Fetch student data
  Future<void> _fetchStudentData() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('Students')
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        setState(() {
          firstName = data['firstName'] ?? '';
          lastName = data['lastName'] ?? '';
          profilePictureUrl = data['profilePictureUrl'] ?? '';
          gender = data['gender'] ?? 'Not specified';
          grade = data['gradeLevel'] ?? 'Not specified';
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching student data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _reauthenticateUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final email = user.email;
        if (email != null) {
          final passwordController = TextEditingController();

          // Show dialog to get the user's password
          await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Reauthenticate'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please enter your password to continue.'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              );
            },
          );

          final password = passwordController.text.trim();
          if (password.isNotEmpty) {
            final credential = EmailAuthProvider.credential(
              email: email,
              password: password,
            );
            await user.reauthenticateWithCredential(credential);
          }
        }
      }
    } catch (e) {
      print('❌ Error during reauthentication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reauthentication failed. Please try again.'),
        ),
      );
    }
  }

  // Delete account and related data
  Future<void> _deleteAccountAndData() async {
    try {
      final studentId = widget.studentId;
      final user = FirebaseAuth.instance.currentUser;

      // Reauthenticate the user before performing sensitive operations
      await _reauthenticateUser();

      // Delete AssignedAssessments
      final assignedAssessments = await FirebaseFirestore.instance
          .collection('Students')
          .doc(studentId)
          .collection('AssignedAssessments')
          .get();
      for (var doc in assignedAssessments.docs) {
        await doc.reference.delete();
      }

      // Delete StudentPerformance
      final performanceDocs = await FirebaseFirestore.instance
          .collection('StudentPerformance')
          .where('studentId', isEqualTo: studentId)
          .get();
      for (var doc in performanceDocs.docs) {
        await doc.reference.delete();
      }

      // Delete from AssignedQuizzes
      final assignedQuizzes = await FirebaseFirestore.instance
          .collection('AssignedQuizzes')
          .where('studentId', isEqualTo: studentId)
          .get();
      for (var doc in assignedQuizzes.docs) {
        await doc.reference.delete();
      }

      // Delete student document
      await FirebaseFirestore.instance
          .collection('Students')
          .doc(studentId)
          .delete();

      // Delete Firebase Auth account
      await user?.delete();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully.")),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        print('❌ Error: Requires recent login.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in again to delete your account.'),
          ),
        );
      } else {
        print("❌ Error deleting account: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete account. Please try again."),
          ),
        );
      }
    }
  }

  // Confirm delete account dialog
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action will permanently delete your account and all related data. This cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccountAndData();
            },
          ),
        ],
      ),
    );
  }

  // Edit name dialog
  void _showEditNameDialog() {
    final TextEditingController firstNameController = TextEditingController(
      text: firstName,
    );
    final TextEditingController lastNameController = TextEditingController(
      text: lastName,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Edit Name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15A323),
              ),
              onPressed: () async {
                final newFirst = firstNameController.text.trim();
                final newLast = lastNameController.text.trim();

                if (newFirst.isNotEmpty && newLast.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('Students')
                      .doc(widget.studentId)
                      .update({'firstName': newFirst, 'lastName': newLast});

                  setState(() {
                    firstName = newFirst;
                    lastName = newLast;
                  });

                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Fetch student performance logs
  Stream<QuerySnapshot> fetchStudentPerformance() {
    return FirebaseFirestore.instance
        .collection('StudentPerformance')
        .where('studentId', isEqualTo: widget.studentId)
        .snapshots();
  }

  // Fetch quiz title
  Future<String> fetchQuizTitle(String quizId) async {
    try {
      DocumentSnapshot quizDoc = await FirebaseFirestore.instance
          .collection('Quizzes')
          .doc(quizId)
          .get();

      if (quizDoc.exists) {
        final data = quizDoc.data() as Map<String, dynamic>;
        return data['title'] ?? 'Untitled Quiz';
      }
      return 'Untitled Quiz';
    } catch (e) {
      print('Error fetching quiz title: $e');
      return 'Untitled Quiz';
    }
  }

  // Build profile section
  Widget _buildProfileSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: profilePictureUrl.isNotEmpty
              ? NetworkImage(profilePictureUrl)
              : const AssetImage("assets/images/default_profile.png")
                    as ImageProvider,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AutoSizeText(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 18,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.black87),
                    tooltip: 'Edit Name',
                    onPressed: _showEditNameDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gender: $gender',
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
              const SizedBox(height: 5),
              Text(
                'Grade Level: $grade',
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build performance header
  Widget _buildPerformanceHeader() {
    return Row(
      children: const [
        Text(
          'Performance Logs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Spacer(),
      ],
    );
  }

  // Build performance logs
  Widget _buildPerformanceLogs() {
    return StreamBuilder<QuerySnapshot>(
      stream: fetchStudentPerformance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No performance logs found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return FutureBuilder<String>(
              future: fetchQuizTitle(data['quizId'] ?? ''),
              builder: (context, quizTitleSnapshot) {
                final quizTitle = quizTitleSnapshot.data ?? 'Loading...';
                return _buildPerformanceCard(data, quizTitle);
              },
            );
          },
        );
      },
    );
  }

  // Build performance card
  Widget _buildPerformanceCard(
    Map<String, dynamic> performance,
    String quizTitle,
  ) {
    final date = performance['timestamp'] != null
        ? (performance['timestamp'] as Timestamp).toDate()
        : null;

    final String oralReadingProfile =
        performance['oralReadingProfile'] ?? 'N/A';
    final String wordReadingLevel = performance['wordReadingLevel'] ?? 'N/A';
    final String comprehensionLevel =
        performance['comprehensionLevel'] ?? 'N/A';
    final String type = performance['type'] ?? 'N/A';

    final int totalMiscues = performance['totalMiscues'] ?? 0;
    final int passageWordCount = performance['passageWordCount'] ?? 0;
    final double wordReadingScore = passageWordCount > 0
        ? ((passageWordCount - totalMiscues) / passageWordCount) * 100
        : 0.0;

    final int totalScore = performance['totalScore'] ?? 0;
    final int totalQuestions = performance['totalQuestions'] ?? 1;
    final double comprehensionScore = (totalScore / totalQuestions) * 100;

    final double readingSpeed = performance['readingSpeed'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quizTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Date: ${date != null ? date.toLocal().toString().split(' ')[0] : 'N/A'}',
            ),
            Text(
              'Word Reading Score: $totalMiscues miscues = ${wordReadingScore.toStringAsFixed(1)}%: $wordReadingLevel',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Comprehension Score: $totalScore out of $totalQuestions = ${comprehensionScore.toStringAsFixed(1)}%: $comprehensionLevel',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Reading Rate: ${readingSpeed.toStringAsFixed(1)} words per minute',
              style: const TextStyle(fontSize: 14),
            ),
            Text('Type: $type', style: const TextStyle(fontSize: 14)),
            const Divider(height: 20, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Oral Reading Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  oralReadingProfile,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getProfileColor(oralReadingProfile),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Get profile color
  Color _getProfileColor(String profile) {
    if (profile == 'Independent') {
      return Colors.green;
    } else if (profile == 'Instructional') {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF15A323),
        centerTitle: true,
      ),
      body: Background(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildProfileSection(),
                    const SizedBox(height: 20),
                    _buildPerformanceHeader(),
                    const SizedBox(height: 10),
                    Expanded(child: _buildPerformanceLogs()),

                    // DELETE BUTTON (placed at bottom)
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _confirmDeleteAccount,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete My Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 24.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
