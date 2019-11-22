import 'package:flutter/material.dart';
import 'package:flutter_douban/constant/color_constant.dart';
import 'package:flutter_douban/constant/text_size_constant.dart';
import '../../constant/constant.dart';

typedef TabCallBack = void Function(int index);

class HotSoonTabBar extends StatefulWidget {
  final state = _HotSoonTabBarState();
  HotSoonTabBar({ Key key, TabCallBack onTabCallBack }) : super(key: key) {
    state.setTabCallBack(onTabCallBack);
  }

  @override
  State<StatefulWidget> createState() {
    return state;
  }

  void setCount(List list) {
    state.setCount(list.length);
  }

  void setComingSoon(List list) {
    state.setComingSoonCount(list.length);
  }
}

class _HotSoonTabBarState extends State<HotSoonTabBar> with SingleTickerProviderStateMixin {
  int movieCount = 0;
  Color selectColor, unselectedColor;
  TextStyle selectStyle, unselectedStyle;
  Widget tabBar;
  TabController _tabController;
  var hotCount, soonCount; //热映数量、即将上映数量、
  TabCallBack onTabCallBack;
  int comingSoonCount = 0;
  int selectIndex = 0;

  @override
  void initState() {
    super.initState();
    selectColor = ColorConstant.colorDefaultTitle;
    unselectedColor = Color.fromARGB(255, 135, 135, 135);
    selectStyle = TextStyle(fontSize: TextSizeConstant.BookAudioPartTabBar, color: selectColor, fontWeight: FontWeight.bold);
    unselectedStyle = TextStyle(fontSize: TextSizeConstant.BookAudioPartTabBar, color: unselectedColor);
    _tabController = TabController(vsync: this, length: 2);
    _tabController.addListener(listener);
    tabBar = TabBar(
      tabs: [
        Padding(padding: const EdgeInsets.only(bottom: Constant.TAB_BOTTOM),child: Text('影院热映')),
        Padding(padding: const EdgeInsets.only(bottom: Constant.TAB_BOTTOM),child: Text('即将上映'))
      ],
      indicatorColor: selectColor,
      labelColor: selectColor,
      labelStyle: selectStyle,
      unselectedLabelColor: unselectedColor,
      unselectedLabelStyle: unselectedStyle,
      indicatorSize: TabBarIndicatorSize.label,
      controller: _tabController,
      isScrollable: true,
    );
  }

  void listener() {
    if (_tabController.indexIsChanging) {
      var index = _tabController.index;
      selectIndex = index;
      setState(() {
        if (index == 0) {
          movieCount = hotCount;
        } else {
          movieCount = comingSoonCount;
        }
        if (onTabCallBack != null) {
          onTabCallBack(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: tabBar, flex: 1),
        Text('全部 $movieCount > ', style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold))
      ],
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(listener);
    _tabController.dispose();
    super.dispose();
  }

  void setCount(int count) {      // 影院热映数量
    setState(() {
      this.hotCount = count;
      if (selectIndex == 0) {
        setState(() {
          movieCount = hotCount;
        });
      }
    });
  }

  void setTabCallBack(TabCallBack onTabCallBack) {
    this.onTabCallBack = onTabCallBack;
  }

  void setComingSoonCount(int length) {     // 即将上映数量
    setState(() {
      this.comingSoonCount = length;
      if (selectIndex == 1) {
        setState(() {
          movieCount = comingSoonCount;
        });
      }
    });
  }

}