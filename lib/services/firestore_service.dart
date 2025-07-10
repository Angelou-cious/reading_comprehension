import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/models/story_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addStory(Story story) async {
    await _firestore.collection('stories').add(story.toMap());
  }

  Future<void> updateStory(String storyId, Story updatedStory) async {
    await _firestore.collection('stories').doc(storyId).update(updatedStory.toMap());
  }

  Future<void> deleteStory(String storyId) async {
    await _firestore.collection('stories').doc(storyId).delete();
  }

  Stream<List<Story>> getStoriesStream() {
    return _firestore.collection('stories').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Story.fromMap(doc.data())).toList(),
    );
  }
}
