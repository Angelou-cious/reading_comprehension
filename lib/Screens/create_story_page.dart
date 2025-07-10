import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reading_comprehension/widgets/background.dart';
import 'dart:ui';

Widget glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

class CreateStoryPage extends StatefulWidget {
  final String teacherId;

  const CreateStoryPage({super.key, required this.teacherId});

  @override
  _CreateStoryPageState createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedType = 'custom';
  String _selectedSet = 'Set A';
  String _selectedGradeLevel = 'Grade 2';
  List<Map<String, dynamic>> _questions = [];
  List<TextEditingController> _questionControllers = [];
  List<List<TextEditingController>> _answerControllers = [];

  @override
  void initState() {
    super.initState();
    _selectedType = 'custom';
    _addQuestion();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'question': '',
        'answers': {'A': '', 'B': '', 'C': ''},
        'correctAnswer': 'A',
      });
      _questionControllers.add(TextEditingController());
      _answerControllers.add([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      _questionControllers[index].dispose();
      _questionControllers.removeAt(index);
      _answerControllers[index].forEach((controller) => controller.dispose());
      _answerControllers.removeAt(index);
    });
  }

  Future<void> _addStoryAndQuiz() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and content cannot be empty'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    List<Map<String, dynamic>> formattedQuestions = [];
    for (int i = 0; i < _questions.length; i++) {
      Map<String, dynamic> questionData = {
        'question': _questionControllers[i].text,
        'correctAnswer': _questions[i]['correctAnswer'],
        'answers': {}
      };

      List<String> answerKeys = _questions[i]['answers'].keys.toList();
      for (int j = 0; j < answerKeys.length; j++) {
        questionData['answers'][answerKeys[j]] = _answerControllers[i][j].text;
      }

      formattedQuestions.add(questionData);
    }

    try {
      DocumentReference storyRef = await FirebaseFirestore.instance
          .collection('Teachers')
          .doc(widget.teacherId)
          .collection('TeacherStories')
          .add({
        'title': _titleController.text,
        'content': _contentController.text,
        'teacherId': widget.teacherId,
        'type': _selectedType,
        'set': _selectedSet,
        'gradeLevel': _selectedGradeLevel,
        'createdAt': Timestamp.now(),
      });

      DocumentReference quizRef = await FirebaseFirestore.instance
          .collection('Teachers')
          .doc(widget.teacherId)
          .collection('TeacherQuizzes')
          .add({
        'title': _titleController.text,
        'storyId': storyRef.id,
        'teacherId': widget.teacherId,
        'type': _selectedType,
        'set': _selectedSet,
        'gradeLevel': _selectedGradeLevel,
        'questions': formattedQuestions,
        'createdAt': Timestamp.now(),
      });

      await storyRef.update({'quizId': quizRef.id});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story and Quiz added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add Story and Quiz: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Story & Quiz", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF15A323),
        centerTitle: true,
      ),
      body: Background(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown('Set', _selectedSet, ['Set A', 'Set B', 'Set C', 'Set D'], (value) {
                  setState(() => _selectedSet = value!);
                }),
                _buildDropdown('Grade Level', _selectedGradeLevel, [
                  'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'
                ], (value) {
                  setState(() => _selectedGradeLevel = value!);
                }),
                _buildTextField(_titleController, 'Title'),
                _buildTextField(_contentController, 'Content', maxLines: 6),
                const Divider(thickness: 2, height: 20),
                _buildQuizQuestions(),
                const SizedBox(height: 10),
                _buildActionButton('💾 Save Story & Quiz', _addStoryAndQuiz, Colors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(color: Color.fromARGB(255, 37, 29, 29))),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
        ),
        onChanged: onChanged,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
        ),
      ),
    );
  }

  Widget _buildQuizQuestions() {
    return Column(
      children: List.generate(_questions.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(_questionControllers[index], 'Question')),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: _questions.length == 1 ? 'Cannot delete the only question' : 'Delete Question',
                      onPressed: _questions.length == 1 ? null : () => _removeQuestion(index),
                    ),

                  ],
                ),
                const SizedBox(height: 10),
                ..._questions[index]['answers'].keys.map((answerKey) {
                  int answerIndex = _questions[index]['answers'].keys.toList().indexOf(answerKey);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _answerControllers[index][answerIndex],
                            decoration: InputDecoration(
                              labelText: 'Answer $answerKey',
                              labelStyle: const TextStyle(color: Colors.black),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Radio<String>(
                          value: answerKey,
                          groupValue: _questions[index]['correctAnswer'],
                          onChanged: (value) {
                            setState(() {
                              _questions[index]['correctAnswer'] = value!;
                            });
                          },
                        ),
                        const Text('Correct'),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Another Question"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15A323),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
