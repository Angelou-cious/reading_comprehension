import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phil/widgets/background.dart';
import 'package:phil/student/student_login.dart'; // Import the StudentLogin page
import 'package:flutter/services.dart'; // Import for TextInputFormatter
import 'package:phil/utils/logger.dart'; // Import the logger utility
import 'package:phil/utils/school_year_util.dart';

class SignUpStudent extends StatefulWidget {
  const SignUpStudent({super.key});

  @override
  State<SignUpStudent> createState() => _SignUpStudentState();
}

class _SignUpStudentState extends State<SignUpStudent> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _teacherCodeController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();
  String? _selectedTeacherId;
  String? _selectedGradeLevel;
  String? _selectedGender;
  String? _selectedSchoolId;
  String? _selectedSchoolName;
  bool _isButtonDisabled = true;
  String? _errorMessage;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _signupCompleted = false;

  @override
  void initState() {
    super.initState();
    _addListeners();

    // Capitalize first letter in first and last names
    _firstNameController.addListener(() {
      String text = _firstNameController.text;
      if (text.isNotEmpty && text[0] != text[0].toUpperCase()) {
        _firstNameController.value = _firstNameController.value.copyWith(
          text: text[0].toUpperCase() + text.substring(1),
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });

    _lastNameController.addListener(() {
      String text = _lastNameController.text;
      if (text.isNotEmpty && text[0] != text[0].toUpperCase()) {
        _lastNameController.value = _lastNameController.value.copyWith(
          text: text[0].toUpperCase() + text.substring(1),
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    if (!_signupCompleted) {
      final currentUser = FirebaseAuth.instance.currentUser;
      currentUser?.delete(); // delete unfinished account
    }
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _teacherCodeController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _addListeners() {
    _emailController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
    _confirmPasswordController.addListener(_validateInputs);
    _firstNameController.addListener(_validateInputs);
    _lastNameController.addListener(_validateInputs);
    _teacherCodeController.addListener(_validateInputs);
    _scoreController.addListener(_validateInputs);
  }

  Future<bool> isEmailAlreadyUsed(String email) async {
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
      email,
    );
    return methods.isNotEmpty;
  }

  Future<void> signUp() async {
    if (_isButtonDisabled) return;

    setState(() {
      _loading = true;
    });

    final email = _emailController.text.trim();

    // ✅ 1. Check if email is already used
    if (await isEmailAlreadyUsed(email)) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This email is already in use.")),
      );
      return;
    }

    try {
      // ✅ 2. Validate Teacher Code
      final teacherDoc = await FirebaseFirestore.instance
          .collection('Teachers')
          .doc(_selectedTeacherId)
          .get();
      if (!teacherDoc.exists ||
          teacherDoc['teacherCode'] != _teacherCodeController.text.trim()) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Teacher code does not match selected teacher."),
          ),
        );
        return;
      }

      // ✅ 3. Create Firebase User
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (user == null) throw Exception("User creation failed.");

      await user.sendEmailVerification();

      final userId = user.uid;
      final schoolYear = await getCurrentSchoolYear();

      final screeningScore = int.tryParse(_scoreController.text) ?? 0;

      // ✅ 4. Store data in Firestore
      await FirebaseFirestore.instance.collection('Students').doc(userId).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': email,
        'teacherId': _selectedTeacherId,
        'teacherCode': _teacherCodeController.text.trim(),
        'gradeLevel': _selectedGradeLevel,
        'gender': _selectedGender,
        'schoolId': _selectedSchoolId,
        'schoolName': _selectedSchoolName,
        'screeningScore': screeningScore,
        'pretestCompleted': false,
        'posttestAssigned': false,
        'createdAt': FieldValue.serverTimestamp(),
        'schoolYear': schoolYear,
      });

      // ✅ 5. Mark signup as complete to avoid deletion
      _signupCompleted = true;

      // ✅ 6. Log success
      await logAction(
        "New student registered: ${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
      );

      await assignPretest(
        userId,
        screeningScore,
        _selectedGradeLevel!,
        schoolYear,
      );

      setState(() => _loading = false);

      // ✅ 7. Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Verify Your Email"),
          content: const Text(
            "A verification link has been sent to your email. Please verify before logging in.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LogInStudent()),
                );
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Registration failed. Please try again.';
      });

      // ✅ Log failure
      await logAction("Student sign-up failed for $email: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
    }
  }

  Future<void> assignPretest(
    String userId,
    int screeningScore,
    String gradeLevel,
    String schoolYear,
  ) async {
    // Skip assignments for scores 14 or above
    if (screeningScore >= 14) {
      return; // No assignment for scores 14 or above
    }

    // Adjust grade level based on the Phil-IRI framework
    int adjustedGradeLevel;
    if (screeningScore <= 7) {
      adjustedGradeLevel =
          int.parse(gradeLevel) - 3; // 3 grade levels below current grade
    } else {
      adjustedGradeLevel =
          int.parse(gradeLevel) - 2; // 2 grade levels below current grade
    }

    // Clamp the adjusted grade level to valid bounds (e.g., Grade 1 to 6)
    adjustedGradeLevel = adjustedGradeLevel.clamp(1, 6);

    // Fetch global assignment counts for sets
    final globalAssignmentsDoc = await FirebaseFirestore.instance
        .collection('GlobalAssignments')
        .doc('assignments')
        .get();

    if (!globalAssignmentsDoc.exists) {
      throw Exception('Global assignments data not found!');
    }

    final assignmentsData = globalAssignmentsDoc.data();
    if (assignmentsData == null) {
      throw Exception('Assignments data is empty!');
    }

    // Determine the least assigned set
    final sets = ['A', 'B', 'C', 'D'];
    String leastAssignedSet = sets.first;
    int leastAssignedCount = assignmentsData['Set A'] ?? 0;

    for (final set in sets) {
      final currentCount = assignmentsData['Set $set'] ?? 0;
      if (currentCount < leastAssignedCount) {
        leastAssignedSet = set;
        leastAssignedCount = currentCount;
      }
    }

    // Increment the count for the selected set in GlobalAssignments
    await FirebaseFirestore.instance
        .collection('GlobalAssignments')
        .doc('assignments')
        .update({'Set $leastAssignedSet': FieldValue.increment(1)});

    // Fetch the appropriate story and quiz based on set and grade level
    final storyQuery = await FirebaseFirestore.instance
        .collection('Stories')
        .where('set', isEqualTo: 'Set $leastAssignedSet')
        .where('type', isEqualTo: 'pretest')
        .where('gradeLevel', isEqualTo: 'Grade $adjustedGradeLevel')
        .limit(1)
        .get();

    final quizQuery = await FirebaseFirestore.instance
        .collection('Quizzes')
        .where('set', isEqualTo: 'Set $leastAssignedSet')
        .where('storyId', isEqualTo: storyQuery.docs.first.id)
        .where('type', isEqualTo: 'pretest')
        .limit(1)
        .get();

    // Check if matching story and quiz exist
    if (storyQuery.docs.isEmpty || quizQuery.docs.isEmpty) {
      throw Exception(
        'No matching stories or quizzes found for Set $leastAssignedSet and Grade $adjustedGradeLevel',
      );
    }

    final storyDoc = storyQuery.docs.first.data();
    final quizDoc = quizQuery.docs.first.data();

    // Assign the story and quiz to the student
    await FirebaseFirestore.instance
        .collection('Students')
        .doc(userId)
        .collection('AssignedAssessments')
        .add({
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedGradeLevel': 'Grade $adjustedGradeLevel',
          'set': leastAssignedSet,
          'type': 'Pretest',
          'quizId': quizQuery.docs.first.id,
          'storyId': storyQuery.docs.first.id,
          'quizTitle': quizDoc['title'],
          'storyTitle': storyDoc['title'],
          'schoolYear': schoolYear,
        });
  }

  void _validateInputs() {
    setState(() {
      bool isFieldsNotEmpty =
          _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty &&
          _firstNameController.text.isNotEmpty &&
          _lastNameController.text.isNotEmpty &&
          _teacherCodeController.text.isNotEmpty &&
          _selectedTeacherId != null &&
          _selectedGradeLevel != null &&
          _selectedGender != null &&
          _scoreController.text.isNotEmpty;
      _isButtonDisabled = isFieldsNotEmpty && _selectedSchoolId != null;

      bool isTeacherCodeValid = _teacherCodeController.text.length == 6;
      bool arePasswordsMatching =
          _passwordController.text == _confirmPasswordController.text;

      if (isFieldsNotEmpty && isTeacherCodeValid && arePasswordsMatching) {
        _isButtonDisabled = false;
        _errorMessage = null;
      } else {
        _isButtonDisabled = true;
        if (!isTeacherCodeValid) {
          _errorMessage = 'Teacher code must be exactly 6 characters long.';
        } else if (!arePasswordsMatching) {
          _errorMessage = 'Passwords do not match.';
        } else {
          _errorMessage = 'Please fill in all fields correctly.';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Background(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white, // makes the form readable
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Student Registration",
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      labelText: "First Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      labelText: "Last Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    hint: const Text("Select Gender"),
                    items: <String>['Male', 'Female'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                        _validateInputs();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Schools')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final schools = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        hint: const Text("Select School"),
                        value: _selectedSchoolId,
                        items: schools.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['name']),
                          );
                        }).toList(),
                        onChanged: (schoolId) {
                          setState(() {
                            _selectedSchoolId = schoolId;
                            _selectedSchoolName = schools.firstWhere(
                              (doc) => doc.id == schoolId,
                            )['name'];
                            _validateInputs();
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select a school' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email),
                      labelText: "Parent's Email Address",
                      helperText: "Email Verification Will Be Sent",
                      helperStyle: (TextStyle(color: Colors.grey)),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Teachers')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var teachers = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        hint: const Text("Select Teacher"),
                        items: teachers.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              '${doc['firstname']} ${doc['lastname']}',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTeacherId = value;
                            _validateInputs();
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _teacherCodeController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.code),
                      labelText: "Teacher Code",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _validateInputs(),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    hint: const Text("Select Grade Level"),
                    items: <String>['5', '6'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('Grade $value'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGradeLevel = value;
                        _validateInputs();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _scoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.school),
                      labelText: "Screening Score",
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (value) {
                      _validateInputs();
                    },
                  ),

                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    onChanged: (_) => _validateInputs(),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: "Confirm Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    onChanged: (_) => _validateInputs(),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const CircularProgressIndicator(color: Colors.green),
                  if (!_loading)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                        onPressed: _isButtonDisabled ? null : signUp,
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
