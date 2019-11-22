import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'package:flutter_douban/router.dart';
import 'package:flutter_douban/widgets/search_text_field_widget.dart';
import 'package:flutter_douban/widgets/my_tab_bar_widget.dart';

var titleList = ['电影', '电视', '综艺', '读书' ];
List<Widget> tabList;

class BookAudioVideoPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _BookAudioVideoPageState();
  }
}

TabController _tabController;
class _BookAudioVideoPageState extends State<BookAudioVideoPage> with SingleTickerProviderStateMixin {
  var tabBar;

  @override
  void initState() {
    super.initState();
    tabBar = HomePageTabBar();
    tabList = getTabList();
    _tabController = TabController(vsync: this, length: tabList.length);  // 添加监听器
  }

  List<Widget> getTabList() {
    return titleList.map((item) => Text('$item', style: TextStyle(fontSize: 15),)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(child: DefaultTabController(length: titleList.length, child: _getNestedScrollView(tabBar))),
    );
  }
}

Widget _getNestedScrollView(Widget tabBar) {
  String hintText = '用一部电影来形容你的2018';
  return NestedScrollView(
    headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
      return <Widget>[
        SliverToBoxAdapter(   // 把一个普通部件包裹成为 Sliver 部件
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10.0),
            child: SearchTextFieldWidget(
              hintText: hintText,
              onTab: (){
                Router.push(context, Router.searchPage, hintText);
              },
            ),
          )
        ),
        SliverPersistentHeader(
          floating: true,   // 滑动是否悬浮
          pinned: true,     // 标题栏是否固定
          delegate: _SliverAppBarDelegate(
            maxHeight: 49.0,
            minHeight: 49.0,
            child: Container(color: Colors.white, child: tabBar)
          ),
        )
      ];
    },
    body: FlutterTabBarView(tabController: _tabController), // 展示内容
  );
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({ @required this.minHeight, @required this.maxHeight, @required this.child });
  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => math.max((minHeight ?? kToolbarHeight), minExtent);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {   // 判断传递参数不一致就重写创建
    return maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
  }
}

class HomePageTabBar extends StatefulWidget {
  HomePageTabBar({ Key key }) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return _HomePageTabBarState();
  }
}

class _HomePageTabBarState extends State<HomePageTabBar> {
  Color selectColor, unselectedColor;
  TextStyle selectStyle, unselectedStyle;

  @override
  void initState() {
    super.initState();
    selectColor = Colors.black;
    unselectedColor = Color.fromARGB(255, 117, 117, 117);
    selectStyle = TextStyle(fontSize: 18, color: selectColor);
    unselectedStyle = TextStyle(fontSize: 18, color: selectColor);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 10.0, bottom: 10.0),
      child: TabBar(
        tabs: tabList,    // 标签
        isScrollable: true,
        controller: _tabController,
        indicatorColor: selectColor,
        labelColor: selectColor,
        labelStyle: selectStyle,
        unselectedLabelColor: unselectedColor,
        unselectedLabelStyle: unselectedStyle,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}