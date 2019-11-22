import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_douban/constant/color_constant.dart';
import 'package:flutter_douban/bean/top_item_bean.dart';

class TopItemWidget extends StatelessWidget {
  final String title;
  final TopItemBean bean;
  final Color partColor;

  TopItemWidget({ Key key, @required this.title, @required this.bean, this.partColor = Colors.brown }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (bean == null) {
      return Container();
    }
    var _imgSize = MediaQuery.of(context).size.width / 5 * 3;
    return Container(
      width: _imgSize,
      height: _imgSize,
      padding: EdgeInsets.only(top: 5.0, right: 10.0, bottom: 5.0),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(5.0)),
        child: Stack(
          children: <Widget>[
            CachedNetworkImage(width: _imgSize, height: _imgSize, fit: BoxFit.cover, imageUrl: bean.imgUrl),
            Positioned(top: 8.0, right: 15.0, child: Text(bean.count, style: TextStyle(fontSize: 12.0, color: Colors.white))),
            Positioned(top: _imgSize / 2 - 40.0, left: 30.0, child: Text(title, style: TextStyle(fontSize: 21.0, color: Colors.white, fontWeight: FontWeight.bold))),
            Positioned(top: _imgSize / 2, child: Padding(
              padding: EdgeInsets.only(top: 10.0, left: 10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: getChildren(bean.items),
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget getItem(Item item, int i) {    // 电影列表
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 5.0, bottom: 5.0),
          child: Text('$i. ${item.title}', style: TextStyle(fontSize: 13.0, color: Colors.white)),
        ),
        Text(
          '${item.average}', style: TextStyle(fontSize: 11.0, color: ColorConstant.colorOrigin),
        )
      ],
    );
  }

  List<Widget> getChildren(List<Item> items) {
    List<Widget> list = [];
    for (int i = 0; i < list.length; i++) {
      list.add(getItem(items[i], i + 1));
    }
    print('list');
    print(list);
    return list;
  }

}