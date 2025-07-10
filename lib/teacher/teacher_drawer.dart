import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reading_comprehension/Screens/privacy_policy_page.dart';
import 'package:reading_comprehension/main.dart';
import 'package:reading_comprehension/teacher/teacher_instruction.dart';
import 'package:reading_comprehension/teacher/teacher_profile.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reading_comprehension/utils/logger.dart';



class TeacherDrawer extends StatefulWidget {
  final String teacherId;

  const TeacherDrawer({super.key, required this.teacherId});

  @override
  State<TeacherDrawer> createState() => _TeacherDrawerState();
}

class _TeacherDrawerState extends State<TeacherDrawer> {
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
    _fetchTeacherData();
  }

Future<void> _requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.camera,
    Permission.storage,
  ].request();

  if (statuses[Permission.camera]!.isDenied || statuses[Permission.storage]!.isDenied) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera and Storage permissions are required.'),
        backgroundColor: Colors.red,
      ),
    );
  } else {
    debugPrint('✅ Permissions granted');
  }
}


 
  Future<void> _fetchTeacherData() async {
  try {
    DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
        .collection('Teachers')
        .doc(widget.teacherId)
        .get();

    if (teacherDoc.exists && mounted) {
      final data = teacherDoc.data() as Map<String, dynamic>;

      setState(() {
        firstName = data['firstname'] ?? '';
        lastName = data['lastname'] ?? '';
        profilePictureUrl = data.containsKey('profilePictureUrl') ? data['profilePictureUrl'] : '';
        isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Error fetching teacher data: $e');
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
      String fileName = '${widget.teacherId}.jpg';
      UploadTask uploadTask = FirebaseStorage.instance
          .ref()
          .child('teacher_profile_pictures/$fileName')
          .putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('Teachers')
          .doc(widget.teacherId)
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
    final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final teacherDoc = await FirebaseFirestore.instance.collection('Teachers').doc(user.uid).get();
  if (teacherDoc.exists) {
    final firstName = teacherDoc['firstname'];
    final lastName = teacherDoc['lastname'];
    await logAction('$firstName $lastName (Teacher): logged out');
  } else {
    await logAction('Unknown Teacher: logged out');
  }
}

      await FirebaseAuth.instance.signOut();


      if (mounted) {
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
              decoration: const BoxDecoration(
                color: Color(0xFF15A323),
              ),
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
                          "Teacher",
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
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text("Profile"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TeacherProfilePage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text("Help"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const TeacherInstructionPage()),
                    );
                  },
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
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  )
                : const Text("Log Out"),
            onTap: isLoggingOut ? null : _logOut,
          ),

        ],
      ),
    );
  }

  void _showAboutUsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "About Us",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "About the Project",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
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