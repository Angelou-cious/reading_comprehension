import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryListWidget extends StatelessWidget {
  final String teacherId;
  final Function(String, String, String) onTapStory;

  const StoryListWidget({super.key, required this.teacherId, required this.onTapStory});

  Future<void> _deleteStoryAndQuiz(BuildContext context, String storyId) async {
    bool confirmed = await _showDeleteConfirmationDialog(context);

    if (confirmed) {
      try {
        // Delete the story
        await FirebaseFirestore.instance.collection('Stories').doc(storyId).delete();

        // Find and delete the associated quiz
        var quizSnapshot = await FirebaseFirestore.instance
            .collection('Quizzes')
            .where('storyId', isEqualTo: storyId)
            .get();

        for (var doc in quizSnapshot.docs) {
          await doc.reference.delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story and associated quiz deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete story and quiz: $e')),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this story and its associated quiz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Stories')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var stories = snapshot.data!.docs;

        return ListView.builder(
          itemCount: stories.length,
          itemBuilder: (context, index) {
            var story = stories[index];
            var title = story['title'] ?? 'No Title';
            var content = story['content'] ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                title: Text(title),
                onTap: () => onTapStory(story.id, title, content),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteStoryAndQuiz(context, story.id), // Trigger deletion with confirmation
                ),
              ),
            );
          },
        );
      },
    );
  }
}
