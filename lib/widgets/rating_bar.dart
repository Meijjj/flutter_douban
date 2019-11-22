import 'package:flutter/material.dart';

class RatingBar extends StatelessWidget {
  var stars;
  final double size;
  final double fontSize;
  final color = Color.fromRGBO(255, 255, 170, 71);

  RatingBar(this.stars, { Key key, this.size = 18.0, this.fontSize = 13.0 }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    stars = stars * 1.0;
    List<Widget> startList = [];
    // 求余获取到实心星星的数量
    var startNumber = stars ~/ 2;

    // 半实心星星   获取评分小数点后面的数字，大于5则有半实星
    var startHalf = 0;
    if (stars.toString().contains('.')) {
      int tmp = int.parse((stars.toString().split('.')[1]));
      if (tmp >= 5) {
        startHalf = 1;
      }
    }

    // 空心星星   等于五颗星减去半实星加上实星的数量 然后依次进入星星
    var startEmpty = 5 - startNumber - startHalf;
    for (var i = 0; i < startNumber; i++) {
      startList.add(Icon(Icons.star, color: color, size: size,));
    }

    if (startHalf > 0) {  // 半实星
      startList.add(Icon(Icons.star_half, color: color, size: size,));
    }
    for (var i = 0; i < startEmpty; i++) {
      startList.add(Icon(Icons.star_border, color: Colors.grey, size: size,));
    }
    startList.add(Text('$stars', style: TextStyle(color: Colors.grey, fontSize: fontSize)));
    return Container(
      alignment: Alignment.topLeft,
      child: Row(children: startList,),
    );
  }

}