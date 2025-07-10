import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'package:reading_comprehension/utils/code_generator.dart';
import 'package:reading_comprehension/teacher/teacher_login.dart';
import 'package:reading_comprehension/utils/logger.dart';
import 'package:reading_comprehension/utils/school_year_util.dart';

class SignUpTeacher extends StatefulWidget {
  const SignUpTeacher({super.key});

  @override
  State<SignUpTeacher> createState() => _SignUpTeacherState();
}

class _SignUpTeacherState extends State<SignUpTeacher> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  String? _selectedSchoolId;
  String? _selectedSchoolName;

  // Track per-field errors
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _schoolError;

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;
  bool _signupCompleted = false; // To track successful signup


  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
    _confirmPasswordController.addListener(_validateInputs);
    _firstNameController.addListener(_validateInputs);
    _lastNameController.addListener(_validateInputs);

    // Auto-capitalize names
    _firstNameController.addListener(() {
      final text = _firstNameController.text;
      if (text.isNotEmpty && text[0] != text[0].toUpperCase()) {
        _firstNameController.value = _firstNameController.value.copyWith(
          text: text[0].toUpperCase() + text.substring(1),
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
    _lastNameController.addListener(() {
      final text = _lastNameController.text;
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
        currentUser?.delete(); // delete unfinished teacher account
      }
      _emailController.dispose();
      _passwordController.dispose();
      _confirmPasswordController.dispose();
      _firstNameController.dispose();
      _lastNameController.dispose();
      super.dispose();
    }


  void _validateInputs() {
    setState(() {
      // Field validation
      _firstNameError = _firstNameController.text.trim().isEmpty ? "First name is required." : null;
      _lastNameError = _lastNameController.text.trim().isEmpty ? "Last name is required." : null;
      _emailError = !_emailController.text.contains('@') ? "Enter a valid email address." : null;
      _passwordError = _passwordController.text.length < 6 ? "Password must be at least 6 characters." : null;
      _confirmPasswordError = _passwordController.text != _confirmPasswordController.text
          ? "Passwords do not match."
          : null;
      _schoolError = _selectedSchoolId == null ? "Please select a school." : null;
    });
  }

  bool get _isFormValid {
    return _firstNameError == null &&
        _lastNameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _schoolError == null &&
        _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _selectedSchoolId != null;
  }

  void _togglePasswordVisibility() => setState(() => _showPassword = !_showPassword);
  void _toggleConfirmPasswordVisibility() => setState(() => _showConfirmPassword = !_showConfirmPassword);

  Future<bool> isEmailAlreadyUsed(String email) async {
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
    return methods.isNotEmpty;
  }

Future<void> signUp() async {
  if (!_isFormValid) return;

  setState(() {
    _loading = true;
  });

  final email = _emailController.text.trim();

  // ✅ Check if email is already used
  if (await isEmailAlreadyUsed(email)) {
    setState(() {
      _loading = false;
      _emailError = 'This email is already in use. Please use a different email.';
    });
    return;
  }

  try {
    // ✅ Create user account
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: _passwordController.text,
    );

    if (userCredential.user == null) {
      throw FirebaseAuthException(code: 'user-creation-failed', message: 'User creation failed.');
    }

    await userCredential.user!.sendEmailVerification();

    final uid = userCredential.user!.uid;
    String teacherCode = await generateAndSaveTeacherCode(uid);
    


    // ✅ Add to Users and Teachers collections
    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'email': email,
      'role': 'teacher',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('Teachers').doc(uid).set({
      'firstname': _firstNameController.text.trim(),
      'lastname': _lastNameController.text.trim(),
      'schoolId': _selectedSchoolId,
      'schoolName': _selectedSchoolName,
      'createdAt': FieldValue.serverTimestamp(),
      'teacherId': uid,
      'teacherCode': teacherCode,
    });

    // ✅ Mark signup as complete so dispose() won't delete account
    _signupCompleted = true;

    // ✅ Log success
    await FirebaseFirestore.instance.collection('Logs').add({
      'message': 'Teacher "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}" created an account',
      'timestamp': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration successful! A verification link has been sent to your email.')),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LogInTeacher()),
      (route) => false,
    );
  } catch (e) {
    setState(() {
      _loading = false;
    });

    String errorMessage = 'Registration failed. Please try again.';
    if (e is FirebaseAuthException) {
      if (e.code == 'email-already-in-use') {
        errorMessage = 'The email address is already in use. Please use a different email.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak. Please choose a stronger password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid. Please enter a valid email.';
      } else if (e.code == 'user-creation-failed') {
        errorMessage = e.message ?? errorMessage;
      }
    }
    setState(() {
      _emailError = errorMessage;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
  }
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
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 80),
              decoration: BoxDecoration(
                color: Colors.white,
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
                children: [
                  const Text(
                    "Teacher Registration",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      labelText: "First Name",
                      border: const OutlineInputBorder(),
                      errorText: _firstNameError,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      labelText: "Last Name",
                      border: const OutlineInputBorder(),
                      errorText: _lastNameError,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SCHOOL DROPDOWN
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('Schools').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                            _selectedSchoolName = schools.firstWhere((doc) => doc.id == schoolId)['name'];
                            _validateInputs();
                          });
                        },
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          errorText: _schoolError,
                        ),
                        validator: (value) => value == null ? 'Please select a school' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email),
                      labelText: "Email Address",
                      helperText: "Email Verification will be sent",
                      border: const OutlineInputBorder(),
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: _togglePasswordVisibility,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: "Confirm Password",
                      border: const OutlineInputBorder(),
                      errorText: _confirmPasswordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: _toggleConfirmPasswordVisibility,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(
                        color: Colors.green,
                      ),
                    ),
                  if (!_loading)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFormValid ? Colors.green : Colors.grey,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                        onPressed: _isFormValid ? signUp : null,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
