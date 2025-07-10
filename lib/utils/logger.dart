import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> logAction(String message) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? 'anonymous';
    final email = currentUser?.email ?? 'unknown';

    await FirebaseFirestore.instance.collection('Logs').add({
      'message': message,
      'userId': userId,
      'email': email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print('Failed to log action: $e');
  }
}
