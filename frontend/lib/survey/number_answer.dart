import 'package:flutter/cupertino.dart';

/* 
  年齡/體重滾輪選擇:
  初始值, 最大最小值, 單位, 跟ChoiceAnswer一樣選擇完傳回Survey
*/
class NumberAnswer extends StatefulWidget{
  const NumberAnswer({
    super.key,
    required this.initial,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged
  });

  final int min;
  final int max;
  final int initial;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<NumberAnswer> createState() => _NumberAnswerState();
}

class _NumberAnswerState extends State<NumberAnswer> {
  late final FixedExtentScrollController _controller = FixedExtentScrollController(initialItem: widget.initial - widget.min);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // ???
    WidgetsBinding.instance.addPostFrameCallback((_)=> widget.onChanged(widget.initial));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 300,
          child: CupertinoPicker(
            scrollController: _controller,
            itemExtent: 50, 
            onSelectedItemChanged: (i) => widget.onChanged(widget.min + i), 
            children:[
              for(int i = widget.min; i < widget.max; i++)
                Center(
                  child: Text(
                    '$i ${widget.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight(800)
                    ),
                    ),
                )
            ]
          )
        )
      ],
    );
  }
}