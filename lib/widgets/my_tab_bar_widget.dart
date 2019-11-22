import 'package:flutter/material.dart';
import 'package:flutter_douban/pages/movie/movie_page.dart';

class FlutterTabBarView extends StatelessWidget {
  final TabController tabController;

  FlutterTabBarView({ Key key, @required this.tabController }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var viewList = [
      MoviePage(key: PageStorageKey<String>('MoviePage')),
      Page2(),
      Page3(),
      Page4()
    ];
    return TabBarView(children: viewList, controller: tabController);
  }
}

class Page2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('page2'),);
  }
}

class Page3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('page3'),);
  }
}

class Page4 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('page4'),);
  }
}