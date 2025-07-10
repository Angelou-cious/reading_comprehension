import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> getCurrentSchoolYear() async {
  final doc = await FirebaseFirestore.instance
      .collection('Settings')
      .doc('SchoolYear')
      .get();

  return doc.data()?['active'] ?? '2024-2025';
}
