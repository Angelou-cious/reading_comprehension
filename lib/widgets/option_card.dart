import 'package:flutter/material.dart';

class OptionCard extends StatelessWidget {
  const OptionCard (
    {super.key, 
  required this.option, 
  required this.color, 
  required this.onTap,});
  final String option;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color,
        child: ListTile(
        title: Text(
        option, 
        textAlign: TextAlign.center,
        style: const TextStyle( 
          fontSize: 22.0,
      
            ),
            
            )
        
      
        ),
      ),
    );

  }




}