import 'package:flutter/material.dart';

class TextAnswer extends StatefulWidget{
  const TextAnswer({
    super.key,
    required this.initial,
    required this.onChanged
  });

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<StatefulWidget> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<TextAnswer> {
  // 在state使用原本widget的變數要用widget.
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  } 
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: TextField(
          style: TextStyle(
            fontSize: 70,
<<<<<<< HEAD
            color: Colors.black
=======
            color: Colors.black,
>>>>>>> bce78eb597e2051b28514809566c5ce7416ab64e
          ),
          controller: _controller,
          onChanged: widget.onChanged,
        ),
      ),
    ); 
  }
}