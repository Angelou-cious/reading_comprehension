import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_sign_up.dart';
import 'student_home_page.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'package:reading_comprehension/utils/logger.dart';

final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

class LogInStudent extends StatefulWidget {
  const LogInStudent({super.key});

  @override
  State<LogInStudent> createState() => _LogInStudentState();
}

class _LogInStudentState extends State<LogInStudent> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscureText = true;
  String? _emailErrorMessage;
  String? _passwordErrorMessage;
  String? _generalErrorMessage;
  bool _loading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _emailErrorMessage = null;
        _passwordErrorMessage = null;
        _generalErrorMessage = null;
        _loading = true;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text,
          password: _password.text,
        );

        // Check the Students collection instead of Users collection
        var studentDoc = await FirebaseFirestore.instance.collection('Students').doc(userCredential.user!.uid).get();

        if (studentDoc.exists) {
        final user = FirebaseAuth.instance.currentUser;

        final firstName = studentDoc['firstName'] ?? 'Student';
        final lastName = studentDoc['lastName'] ?? '';

        // Allow old accounts that don’t have verification status
        final isEmailVerified = user?.emailVerified ?? false;

        // If user registered before verification requirement, let them in
        final createdAt = studentDoc['createdAt'];
        final createdDate = (createdAt is Timestamp) ? createdAt.toDate() : null;

         if (isEmailVerified || (createdDate != null && createdDate.isBefore(DateTime(2025, 5, 11)))) {
          await FirebaseFirestore.instance.collection('Logs').add({
            'message': 'Student "$firstName $lastName" signed in',
            'timestamp': Timestamp.now(),
          });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StudentHomePage(studentId: user!.uid),
            ),
          );
        } else {
          setState(() {
            _generalErrorMessage = "Please verify your email before logging in.";
            _loading = false;
          });
          await FirebaseAuth.instance.signOut();
        }
      }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _loading = false;

          if (e.code == 'user-not-found') {
            _emailErrorMessage = 'No user found with this email.';
          } else if (e.code == 'wrong-password') {
            _passwordErrorMessage = 'Incorrect password. Please try again.';
          } else if (e.code == 'invalid-email') {
            _emailErrorMessage = 'Invalid email format.';
          } else {
            _generalErrorMessage = 'Login failed. Please check your email and password.';
          }
        });
      } catch (e) {
        setState(() {
          _loading = false;
          _generalErrorMessage = 'Login failed. Please check your email and password.';
        });
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Background(
    child: Scaffold(
      resizeToAvoidBottomInset: true, // Allow layout to adjust when the keyboard is shown
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Form(
                  key: _formKey,
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo Section
                        SizedBox(
                          height: 300,
                          width: 400,
                          child: Image.asset(
                            "assets/images/logo.png",
                            fit: BoxFit.fill,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Welcome Text
                        const Text(
                          "Welcome Back, Student!",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        // Email Input
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          controller: _email,
                          validator: (email) =>
                              email!.isNotEmpty ? null : 'Please enter your email',
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email),
                            labelText: "Parent's Email Address",
                            hintText: "Please Enter Your Email",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_emailErrorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _emailErrorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Password Input
                        TextFormField(
                          controller: _password,
                          obscureText: _obscureText,
                          validator: (pwd) =>
                              pwd!.length >= 6 ? null : 'Password must be at least 6 characters',
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureText ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                            labelText: "Password",
                            hintText: "Please Enter Your Password",
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (_passwordErrorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _passwordErrorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // General Error Message
                        if (_generalErrorMessage != null) ...[
                          Text(
                            _generalErrorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Forgot Password Section
                        TextButton(
                            onPressed: () async {
                            if (_email.text.isEmpty) {
                            setState(() {
                            _emailErrorMessage = 'Please enter your email first.';
                                 });
                            return;
                          }

                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
                            );
                          } on FirebaseAuthException catch (e) {
                            setState(() {
                              _generalErrorMessage = 'Error: ${e.message}';
                            });
                          }
                        },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 25),
                        // Login Button
                        if (_loading)
                          const CircularProgressIndicator(color: Colors.green)
                        else
                          SizedBox(
                            height: 50,
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15A323),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _login,
                              child: const Text(
                                "Sign In as Student",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Sign Up Section
                        Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.green.withOpacity(0.6),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text(
        "Don't have an account? ",
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SignUpStudent(),
            ),
          );
        },
        child: const Text(
          "Sign Up Now!",
          style: TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
           
          ),
        ),
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
        },
      ),
    ),
  );
}

}
