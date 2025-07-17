import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_scaffold.dart';

class ManageContentPage extends StatefulWidget {
  const ManageContentPage({super.key});

  @override
  State<ManageContentPage> createState() => _ManageContentPageState();
}

class _ManageContentPageState extends State<ManageContentPage> {
  // --- Story fields
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _gradeLevel = 'Grade 5';
  String _set = 'Set A';
  String _type = 'pretest';

  // --- Quiz fields
  List<Map<String, dynamic>> _quizQuestions = [];

  // For quizzes editing
  void showQuizEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    List questions = data['questions'] ?? [];
    List<Map<String, dynamic>> editableQuestions = questions
        .map<Map<String, dynamic>>((q) => {
              'question': q['question'] ?? '',
              'answers': {
                'A': q['answers']['A'] ?? '',
                'B': q['answers']['B'] ?? '',
                'C': q['answers']['C'] ?? '',
                'D': q['answers']['D'] ?? ''
              },
              'correctAnswer': q['correctAnswer'] ?? 'A'
            })
        .toList();
    if (editableQuestions.isEmpty) {
      editableQuestions.add({
        'question': '',
        'answers': {'A': '', 'B': '', 'C': '', 'D': ''},
        'correctAnswer': 'A'
      });
    }
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Quiz: ${data['title'] ?? ''}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: editableQuestions.length,
                    itemBuilder: (ctx, idx) {
                      var q = editableQuestions[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                initialValue: q['question'],
                                decoration: const InputDecoration(labelText: 'Question'),
                                onChanged: (v) => q['question'] = v,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  for (var ansKey in ['A', 'B', 'C', 'D'])
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        child: TextFormField(
                                          initialValue: q['answers'][ansKey] ?? '',
                                          decoration: InputDecoration(labelText: ansKey),
                                          onChanged: (v) => q['answers'][ansKey] = v,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text("Correct: "),
                                  DropdownButton<String>(
                                    value: q['correctAnswer'],
                                    items: ['A', 'B', 'C', 'D']
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: (val) => setState(() => q['correctAnswer'] = val!),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: editableQuestions.length > 1
                                        ? () {
                                            setState(() {
                                              editableQuestions.removeAt(idx);
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Question"),
                      onPressed: () {
                        setState(() {
                          editableQuestions.add({
                            'question': '',
                            'answers': {'A': '', 'B': '', 'C': '', 'D': ''},
                            'correctAnswer': 'A'
                          });
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15A323)),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('Quizzes').doc(doc.id).update({
                  'questions': editableQuestions,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Update Quiz'),
            ),
          ],
        ),
      ),
    );
  }

  // For stories + quiz ADD
  void showStoryQuizDialog(BuildContext context, [DocumentSnapshot? doc]) {
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _contentController.text = data['content'] ?? '';
      _gradeLevel = data['gradeLevel'] ?? 'Grade 5';
      _set = data['set'] ?? 'Set A';
      _type = data['type'] ?? 'pretest';
      _quizQuestions = [
        {
          'question': '',
          'answers': {'A': '', 'B': '', 'C': '', 'D': ''},
          'correctAnswer': 'A'
        }
      ];
    } else {
      _titleController.clear();
      _contentController.clear();
      _gradeLevel = 'Grade 5';
      _set = 'Set A';
      _type = 'pretest';
      _quizQuestions = [
        {
          'question': '',
          'answers': {'A': '', 'B': '', 'C': '', 'D': ''},
          'correctAnswer': 'A'
        }
      ];
    }
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(doc == null ? 'Add Passage and Quiz' : 'Edit Passage (Quiz not editable here)'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Passage Title', border: OutlineInputBorder()),
                      validator: (v) => v!.trim().isEmpty ? 'Enter title' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contentController,
                      decoration: InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
                      validator: (v) => v!.trim().isEmpty ? 'Enter content' : null,
                      minLines: 4,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gradeLevel,
                            items: ['Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'].map((g) =>
                              DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => _gradeLevel = val!),
                            decoration: const InputDecoration(labelText: 'Grade Level', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _set,
                            items: ['Set A', 'Set B', 'Set C', 'Set D'].map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _set = val!),
                            decoration: const InputDecoration(labelText: 'Set', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _type,
                      items: ['pretest', 'post test', 'custom'].map((t) =>
                        DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                      onChanged: (val) => setState(() => _type = val!),
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    ),
                    if (doc == null) ...[
                      const Divider(height: 30, thickness: 1),
                      Text("Comprehension Quiz", style: Theme.of(context).textTheme.titleMedium),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _quizQuestions.length,
                        itemBuilder: (ctx, idx) {
                          var q = _quizQuestions[idx];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    initialValue: q['question'],
                                    decoration: const InputDecoration(labelText: 'Question'),
                                    onChanged: (v) => q['question'] = v,
                                    validator: (v) => v!.isEmpty ? 'Enter question' : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      for (var ansKey in ['A', 'B', 'C', 'D'])
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                            child: TextFormField(
                                              initialValue: q['answers'][ansKey],
                                              decoration: InputDecoration(labelText: ansKey),
                                              onChanged: (v) => q['answers'][ansKey] = v,
                                              validator: (v) => v!.isEmpty ? 'Required' : null,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text("Correct: "),
                                      DropdownButton<String>(
                                        value: q['correctAnswer'],
                                        items: ['A', 'B', 'C', 'D']
                                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                            .toList(),
                                        onChanged: (val) => setState(() => q['correctAnswer'] = val!),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: _quizQuestions.length > 1
                                            ? () {
                                                setState(() {
                                                  _quizQuestions.removeAt(idx);
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Add Question"),
                          onPressed: () {
                            setState(() {
                              _quizQuestions.add({
                                'question': '',
                                'answers': {'A': '', 'B': '', 'C': '', 'D': ''},
                                'correctAnswer': 'A'
                              });
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15A323)),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (doc == null) {
                    // Add new story + quiz
                    final storyDoc = await FirebaseFirestore.instance.collection('Stories').add({
                      'title': _titleController.text,
                      'content': _contentController.text,
                      'gradeLevel': _gradeLevel,
                      'set': _set,
                      'type': _type,
                      'isDefault': false,
                    });
                    final quizDoc = await FirebaseFirestore.instance.collection('Quizzes').add({
                      'title': _titleController.text + " Quiz",
                      'questions': _quizQuestions,
                      'type': _type,
                      'set': _set,
                      'storyId': storyDoc.id,
                      'gradeLevel': _gradeLevel,
                      'isDefault': false,
                    });
                    await FirebaseFirestore.instance.collection('Stories').doc(storyDoc.id).update({
                      'quizId': quizDoc.id,
                    });
                  } else {
                    // Update only the story (not quiz here)
                    await FirebaseFirestore.instance.collection('Stories').doc(doc.id).update({
                      'title': _titleController.text,
                      'content': _contentController.text,
                      'gradeLevel': _gradeLevel,
                      'set': _set,
                      'type': _type,
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(doc == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Story/passages list with delete and edit
  Widget buildStoryList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Stories').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Error loading data');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: ExpansionTile(
            title: const Text('Passages (Story + Quiz)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF15A323)),
              onPressed: () => showStoryQuizDialog(context),
            ),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['content'] ?? 'No Content'),
                trailing: Wrap(
                  spacing: 10,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => showStoryQuizDialog(context, doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        // HCI-compliant warning
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Deletion'),
                            content: const Text('Deleting this passage will also delete the linked quiz. This cannot be undone. Proceed?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          // Delete quiz first if quizId exists
                          if (data['quizId'] != null && (data['quizId'] as String).isNotEmpty) {
                            await FirebaseFirestore.instance.collection('Quizzes').doc(data['quizId']).delete();
                          }
                          await FirebaseFirestore.instance.collection('Stories').doc(doc.id).delete();
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Quiz list (edit and delete)
  Widget buildQuizList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Quizzes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Error loading quizzes');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: ExpansionTile(
            title: const Text('Quizzes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['questions'] == null
                    ? 'No questions'
                    : 'Questions: ${(data['questions'] as List).length}'),
                trailing: Wrap(
                  spacing: 10,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => showQuizEditDialog(context, doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Deletion'),
                            content: const Text('Delete this quiz? This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await FirebaseFirestore.instance.collection('Quizzes').doc(doc.id).delete();
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Manage Content',
      showAppBar: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Content Management",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF15A323),
            ),
          ),
          const SizedBox(height: 12),
          buildStoryList(context),
          buildQuizList(context),
        ],
      ),
    );
  }
}
