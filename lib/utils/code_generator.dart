import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

String generateTeacherCode(int length) {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random();
  return String.fromCharCodes(Iterable.generate(
    length, (_) => characters.codeUnitAt(random.nextInt(characters.length))));
}




Future<bool> checkCodeUniqueness(String code) async {
  var snapshot = await FirebaseFirestore.instance
      .collection('Teachers')
      .where('teacherCode', isEqualTo: code)
      .get();

  return snapshot.docs.isEmpty;
}


Future<String> generateAndSaveTeacherCode(String teacherId) async {
  String newCode = generateTeacherCode(6);
  print("Generated code: $newCode");

  // Ensure the code is unique
  bool isUnique = await checkCodeUniqueness(newCode);
  print("Is code unique? $isUnique");

  // If the code is not unique, generate a new one
  while (!isUnique) {
    newCode = generateTeacherCode(6);
    print("Generated new code: $newCode");
    isUnique = await checkCodeUniqueness(newCode);
  }

  // Save the code to Firestore using `set` with merge: true to avoid the NOT_FOUND error
  print("Saving code $newCode to Firestore...");
  await FirebaseFirestore.instance.collection('Teachers').doc(teacherId).set({
    'teacherCode': newCode,
  }, SetOptions(merge: true)); // Using merge to ensure no data is overwritten if the document exists
  print("Code saved successfully.");

  return newCode;
}

