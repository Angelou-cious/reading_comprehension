import 'package:flutter/material.dart';
import '../constant.dart';

class NextButton extends StatelessWidget {
  const NextButton({super.key, required this.nextQuestion});
  final VoidCallback nextQuestion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400, // Adjust the width as needed
      height: 40, // Adjust the height as needed
      child: FloatingActionButton(
        onPressed: nextQuestion,
        backgroundColor: neutralColor,
        child: const Padding(
          padding: EdgeInsets.all(8.0), // Adjust padding as needed
          child: Text(
            'Next Question',
            textAlign: TextAlign.center,
            // ignore: unnecessary_const
            style: const TextStyle(fontSize: 16), // Adjust font size as needed
          ),
        ),
      ),
    );
  }
}
