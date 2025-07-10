import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_sign_up.dart';
import 'teacher_homepage.dart';
import 'package:reading_comprehension/widgets/background.dart'; // Import your Background widget
import 'package:reading_comprehension/utils/logger.dart';

final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

class LogInTeacher extends StatefulWidget {
  const LogInTeacher({super.key});

  @override
  State<LogInTeacher> createState() => _LogInTeacherState();
}

class _LogInTeacherState extends State<LogInTeacher> {
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

var user = userCredential.user;
var userDoc = await FirebaseFirestore.instance.collection('Users').doc(user!.uid).get();

if (!user.emailVerified) {
  DateTime cutoff = DateTime(2025, 5, 11);
  bool isNewAccount = false;

  if (userDoc.exists && userDoc.data()!.containsKey('createdAt')) {
    Timestamp createdAt = userDoc['createdAt'];
    isNewAccount = createdAt.toDate().isAfter(cutoff);
  } else {
    // Treat accounts without createdAt as old
    isNewAccount = false;
  }

  if (isNewAccount) {
    await user.sendEmailVerification();
    await FirebaseAuth.instance.signOut();
    setState(() {
      _generalErrorMessage = 'Please verify your email. A verification link has been sent.';
      _loading = false;
    });
    return;
  } else {
    debugPrint('Skipping verification for old account.');
  }
}







if (userDoc.exists && userDoc.data()!['role'] == 'teacher') {
  final teacherDoc = await FirebaseFirestore.instance.collection('Teachers').doc(userCredential.user!.uid).get();
final firstName = teacherDoc['firstname'] ?? '';
final lastName = teacherDoc['lastname'] ?? '';

await FirebaseFirestore.instance.collection('Logs').add({
  'message': 'Teacher "$firstName $lastName" signed in',
  'timestamp': Timestamp.now(),
});
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => TeacherHomePage(teacherId: userCredential.user!.uid),
    ),
  );
} else {
  throw Exception('Not authorized as teacher');
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
      resizeToAvoidBottomInset: true, // Allow the layout to adjust when the keyboard appears
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
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
                          "Welcome Back, Teacher!",
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
                          validator: (email) => email!.isNotEmpty ? null : 'Please enter your email',
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email),
                            labelText: "Email Address",
                            hintText: "Please Enter Your Email",
                           
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_emailErrorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _emailErrorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Password Input
                        TextFormField(
                          controller: _password,
                          obscureText: _obscureText,
                          validator: (pwd) => pwd!.length >= 6 ? null : 'Password must be at least 6 characters',
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
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
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // General Error Message
                        if (_generalErrorMessage != null) ...[
                          Text(
                            _generalErrorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                                "Sign In as Teacher",
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
              builder: (context) => const SignUpTeacher(),
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
