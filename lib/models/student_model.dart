import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id; // Add an id field
  final String firstName;
  final String lastName;
  final String gradeLevel;
  final String gender;
  final String profilePictureUrl;
  final String email;
  final Map<String, dynamic> progress;


  Student({
    required this.id, // Include id in the constructor
    required this.firstName,
    required this.lastName,
    required this.gradeLevel,
    required this.gender,
    required this.profilePictureUrl,
    required this.progress,
    required this.email,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) { // Use DocumentSnapshot
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id, // Assign the document ID here
      firstName: data['firstName'] ?? 'Unknown',
      lastName: data['lastName'] ?? 'Unknown',
      gradeLevel: data['gradeLevel'] ?? 'Unknown',
      gender: data['gender'] ?? 'Unknown',
      profilePictureUrl: data['profilePictureUrl'] ?? '',
      progress: data['progress'] ?? {},
      email: data['email'] ?? 'N/A',
    );
  }
}
