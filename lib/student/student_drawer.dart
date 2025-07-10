import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reading_comprehension/student/profile_page.dart';
import 'package:reading_comprehension/main.dart';
import 'package:reading_comprehension/Screens/privacy_policy_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reading_comprehension/utils/logger.dart';

class StudentDrawer extends StatefulWidget {
  final String studentId;

  const StudentDrawer({super.key, required this.studentId});

  @override
  State<StudentDrawer> createState() => _StudentDrawerState();
}

class _StudentDrawerState extends State<StudentDrawer> {
  String firstName = '';
  String lastName = '';
  String profilePictureUrl = '';
  bool isLoading = true;
  bool isLoggingOut = false;
  bool showCameraIcon = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }
Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    
    final cameraStatus = await Permission.camera.request();
    final photosStatus = await Permission.photos.request(); 

    if (!cameraStatus.isGranted || !photosStatus.isGranted) {
      openAppSettings(); // Prompt user if denied
    }
  } else {
    await Permission.camera.request();
    await Permission.photos.request();
  }
}


  Future<void> _fetchStudentData() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('Students')
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists && mounted) {
        setState(() {
          firstName = studentDoc['firstName'];
          lastName = studentDoc['lastName'];
          profilePictureUrl = studentDoc.data().toString().contains('profilePictureUrl')
              ? studentDoc['profilePictureUrl']
              : '';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching student data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

Future<void> _uploadProfilePicture() async {
  try {
    await _requestPermissions();

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);

      File file = File(pickedFile.path);
      String fileName = '${widget.studentId}.jpg';
      UploadTask uploadTask = FirebaseStorage.instance
          .ref()
          .child('teacher_profile_pictures/$fileName')
          .putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('Students')
          .doc(widget.studentId)
          .update({'profilePictureUrl': downloadUrl});

      if (!mounted) return;
      setState(() {
        profilePictureUrl = downloadUrl;
        showCameraIcon = false;
      });
    }
  } catch (e) {
    debugPrint('Error uploading profile picture: $e');
  } finally {
    if (!mounted) return;
    setState(() => _isUploading = false);
  }
}


Future<void> _logOut() async {
  if (!mounted) return;

  setState(() {
    isLoggingOut = true;
  });

  try {
    // Properly log out from Firebase
   final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final studentDoc = await FirebaseFirestore.instance.collection('Students').doc(user.uid).get();
  if (studentDoc.exists) {
    final firstName = studentDoc['firstName'];
    final lastName = studentDoc['lastName'];
    await logAction('$firstName $lastName (Student): logged out');
  } else {
    await logAction('Unknown Student: logged out');
  }
}

    await FirebaseAuth.instance.signOut();


    if (mounted) {
      // Navigate to splash/login page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MyHomePage()),
        (route) => false,
      );
    }
  } catch (e) {
    debugPrint('Error during logout: $e');
    setState(() {
      isLoggingOut = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF15A323)),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isUploading
                              ? null
                              : () {
                                  setState(() {
                                    showCameraIcon = !showCameraIcon;
                                  });
                                },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                maxRadius: 50,
                                backgroundImage: profilePictureUrl.isNotEmpty
                                    ? NetworkImage(profilePictureUrl)
                                    : const AssetImage("assets/images/default_profile.png") as ImageProvider,
                              ),
                              if (showCameraIcon && !_isUploading)
                                Positioned(
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: _uploadProfilePicture,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.camera_alt, color: Colors.white, size: 30),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isUploading)
                                const Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "$firstName $lastName",
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          "Student",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home_filled),
                  title: const Text("Home"),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text("Profile"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(studentId: widget.studentId),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text("Help"),
                  onTap: _showHelpDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text("About Us"),
                  onTap: _showAboutUsDialog,
                ),
                 ListTile(
                leading: const Icon(Icons.library_books),
                title: const Text("Privacy Policy"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              ],
            ),
          ),
          const Divider(thickness: 1, color: Colors.black),
          ListTile(
            leading: const Icon(Icons.logout),
            title: isLoggingOut
                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green))
                : const Text("Log Out"),
            onTap: isLoggingOut ? null : _logOut,
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return const AlertDialog(
          title: Text("Help"),
          content: Text("This is a reading comprehension app for students to take assessments and track progress."),
        );
      },
    );
  }

  void _showAboutUsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("About Us", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("About the Project", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(height: 8),
                Text(
                  "CISC KIDS is a mobile reading comprehension app designed to integrate the Philippine Informal Reading Inventory (Phil-IRI). "
                  "Phil-IRI is a reading assessment tool developed by the Department of Education (DepEd) to measure students' reading levels and "
                  "help educators design interventions to improve literacy skills.",
                ),
                SizedBox(height: 16),
                Text("Developer:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("  Dan Ephraim Macabenlar"),
                Text("Researcher:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("  Angelou Lapad"),
                SizedBox(height: 16),
                Text("Advisory Committee:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("• Gladys Ayunar"),
                Text("• Kent Bonifacio"),
                Text("• Nathalie Casildo"),
                Text("• Jinky Marcelo"),
                SizedBox(height: 16),
                Text("Purpose:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "Our goal is to provide teachers with an efficient platform to assess and monitor their students' reading comprehension skills "
                  "and design effective interventions to improve literacy rates among young learners.",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
