import 'package:flutter/material.dart';
import 'package:flutter_douban/pages/home/home_page.dart';
import 'package:flutter_douban/pages/movie/book_audio_video_page.dart';

// 整个app最外层的容器
class ContainersPage extends StatefulWidget {
  ContainersPage({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ContainersPageState();
  }
}

class _Item {
  String name, activeIcon, normalIcon;
  _Item(this.name, this.activeIcon, this.normalIcon);
}

class _ContainersPageState extends State<ContainersPage> {
//  final ShopPageWidget shopPageWidget = ShopPageWidget();
  List<Widget> pages;
  final defaultItemColor = Color.fromARGB(255, 125, 125, 125);
  final itemNames = [
    _Item('首页', 'assets/images/ic_tab_home_active.png', 'assets/images/ic_tab_home_normal.png'),
    _Item('书影音', 'assets/images/ic_tab_subject_active.png', 'assets/images/ic_tab_subject_normal.png'),
    _Item('小组', 'assets/images/ic_tab_group_active.png', 'assets/images/ic_tab_group_normal.png'),
    _Item('市集', 'assets/images/ic_tab_shiji_active.png', 'assets/images/ic_tab_shiji_normal.png'),
    _Item('我的', 'assets/images/ic_tab_profile_active.png', 'assets/images/ic_tab_profile_normal.png')
  ];

  List<BottomNavigationBarItem> itemList;

  @override
  void initState() {
    super.initState();
    if (pages == null) {
      pages = [
        HomePage(),
        BookAudioVideoPage()
      ];
    }
    // 底部导航栏的展示
    if (itemList == null) {
      itemList = itemNames.map((item) => BottomNavigationBarItem(
        icon: Image.asset(
          item.normalIcon,
          width: 30.0,
          height: 30.0,
        ),
        title: Text(
          item.name,
          style: TextStyle(fontSize: 10.0),
        ),
        activeIcon: Image.asset(item.activeIcon, width: 30.0, height: 30.0)
      )).toList();
    }
  }

  @override
  void didUpdateWidget(ContainersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  int _selectIndex = 0;
  // stack( 层叠布局 ) + offstage 解决状态被重置
  // 根据点击的index来显示对应的page
  Widget _getPagesWidget(int index) {
    return Offstage(
      offstage: _selectIndex != index,
      child: TickerMode(
        enabled: _selectIndex == index,
        child: pages[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: new Stack(
        children: [
          _getPagesWidget(0),
          _getPagesWidget(1),
//          _getPagesWidget(2),
//          _getPagesWidget(3),
//          _getPagesWidget(4),
      ],
    ),
    backgroundColor: Color.fromARGB(255, 248, 248, 248),
    bottomNavigationBar: BottomNavigationBar(
      items: itemList,
      onTap: (int index) {
        ///这里根据点击的index来显示，非index的page均隐藏
        setState(() {
          _selectIndex = index;
        });
      },
      iconSize: 24,
      currentIndex: _selectIndex,
      fixedColor: Color.fromARGB(255, 0, 188, 96),
      type: BottomNavigationBarType.fixed,
    )
    );
  }
}