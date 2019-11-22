import 'package:flutter/material.dart';
import 'package:flutter_douban/widgets/search_text_field_widget.dart';
import 'package:flutter_douban/pages/home/home_app_bar.dart' as myapp;
import 'package:flutter_douban/bean/subject_entity.dart';
import 'package:flutter_douban/constant/constant.dart';
import 'package:flutter_douban/http/http_request.dart';
import 'package:flutter_douban/http/mock_request.dart';
import 'package:flutter_douban/http/API.dart';
import 'package:flutter_douban/router.dart';
import 'package:flutter_douban/widgets/image/radius_img.dart';
import 'package:flutter_douban/widgets/video_widget.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('build homePage');
    return getWidget();
  }
}

var _tabs = ['动态', '推荐'];
DefaultTabController getWidget() {
  // 无状态控件
  return DefaultTabController(
    initialIndex: 1,
    length: _tabs.length,
    child: NestedScrollView(headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
      return <Widget>[
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          child: myapp.SliverAppBar(
            pinned: true, // 列表在滚动的时候appbar是否一直保持可见
            expandedHeight: 120.0, // 展开最大高度
            primary: true,
            titleSpacing: 0.0,
            backgroundColor: Colors.white,
            // 显示的背景
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: Colors.green,
                child: SearchTextFieldWidget(
                  hintText: '影视作品中你难忘的离别',
                  margin: const EdgeInsets.only(left: 15.0, right: 15.0),
                  onTab: () {
                    Router.push(context, Router.searchPage, '影视作品中你难忘的离别');
                  }
                ),
                alignment: Alignment(0.0, 0.0),
              ),
            ),
            bottomTextString: _tabs,
            bottom: TabBar(
              tabs: _tabs.map((String name) => Container(child: Text(name), padding: const EdgeInsets.only(bottom: 5.0),)).toList(),
            )
          ),
        )
      ];
    },
      body: TabBarView( // 选项卡视图内容
        children: _tabs.map((String name) {
          return SliverContainer(name: name);
        }).toList()
      ),
    )
  );
}

class SliverContainer extends StatefulWidget {
  final String name;
  SliverContainer({ Key key, @required this.name }) : super(key: key);

  @override
  _SliverContainerState createState() => _SliverContainerState();
}

class _SliverContainerState extends State<SliverContainer> {
  @override
  void initState() {
    super.initState();
    // 请求动态数据
    if (list == null || list.isEmpty) {
      if (_tabs[0] == widget.name) {
        requestAPI();
      } else {
        requestAPI();
      }
    }
  }

  List<Subject> list;
  void requestAPI() async {
    var _request = MockRequest();
    var result = await _request.get(API.TOP_250);
    var resultList = result['subjects'];
    list = resultList.map<Subject>((item) => Subject.fromMap(item)).toList();
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return getContentSliver(context, list);
  }

  getContentSliver(BuildContext context, List<Subject> list) {
    if (widget.name == _tabs[0]) {
      // 动态页显示登录界面
      return _loginContainer(context);
    }
    if (list == null || list.length == 0) {
      return Text('暂无数据');
    }
    return SafeArea(
      top: false,
      bottom: false,
      child: Builder(
          builder: (BuildContext context) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              key: PageStorageKey<String>(widget.name),
              slivers: <Widget>[    // widget数组
                SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),),   // 记录吸收重叠的对象
                SliverList(
                  delegate: SliverChildBuilderDelegate(   // 根据视图渲染当前出现的元素
                    ((BuildContext context, int index) {
                      return getCommonItem(list, index);
                    }), childCount: list.length)),
              ],
            );
          }
      ),
    );
  }

  double singleLineImgHeight = 180.0;
  double contentVideoHeight = 350.0;
  getCommonItem(List<Subject> items, int index) {
    Subject item = items[index];
    bool showVideo = index == 1 || index == 3;    // 区分出视频和图片
    return Container(
      height: showVideo ? contentVideoHeight : singleLineImgHeight,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.only(left: Constant.MARGIN_LEFT, right: Constant.MARGIN_RIGHT, top: Constant.MARGIN_RIGHT, bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(    // 顶部内容
            children: <Widget>[
              CircleAvatar(
                radius: 25.0,
                backgroundImage: NetworkImage(item.casts[0].avatars.medium),
                backgroundColor: Colors.white,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Text(item.title),
              ),
              Expanded(
                child: Align(
                  child: Icon(
                    Icons.more_horiz,
                    color: Colors.grey,
                    size: 18.0,
                  ),
                  alignment: Alignment.centerRight,
                ),
              ),
            ],
          ),
          Expanded( // 展示图片或者视频
            child: Container(
              child: showVideo ? getContentVideo(index) : getItemCenterImg(item),
            ),
          ),
          Padding(  // 底部按钮操作
            padding: const EdgeInsets.only(left: 15.0, right: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Image.asset(
                  Constant.ASSETS_IMG + 'ic_vote.png',
                  width: 25.0,
                  height: 25.0,
                ),
                Image.asset(
                  Constant.ASSETS_IMG + 'ic_notification_tv_calendar_comments.png',
                  width: 20.0,
                  height: 20.0,
                ),
                Image.asset(
                  Constant.ASSETS_IMG + 'ic_status_detail_reshare_icon.png',
                  width: 25.0,
                  height: 25.0,
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  getItemCenterImg(Subject item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Expanded(
          child: RadiusImg.get(
            item.images.large,
            null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(5.0), bottomLeft: Radius.circular(5.0))
            )
          ),
        ),
        Expanded(
          child: RadiusImg.get(item.casts[1].avatars.medium, null, radius: 0.0),
        ),
        Expanded(
          child: RadiusImg.get(item.casts[2].avatars.medium, null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(5.0), bottomRight: Radius.circular(5.0))),
          )
        )
      ],
    );
  }

  getContentVideo(int index) {
    if (!mounted) {
      return Container();
    }
    return VideoWidget(index == 1 ? Constant.URL_MP4_DEMO_0 : Constant.URL_MP4_DEMO_1, showProgressBar: false);
  }
}

_loginContainer(BuildContext context) {
  return Align(
    alignment: Alignment(0, 0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Image.asset(
          Constant.ASSETS_IMG + 'ic_new_empty_view_default.png',
          width: 120.0,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 15.0, bottom: 25.0),
          child: Text(
            '登录后查看关注人动态', style: TextStyle(fontSize: 16.0, color: Colors.grey),
          ),
        ),
        GestureDetector(
          child: Container(
            child: Text('去登录', style: TextStyle(fontSize: 16.0, color: Colors.green)),
            padding: const EdgeInsets.only(left: 35.0, right: 35.0, top: 8.0, bottom: 8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green),
              borderRadius: const BorderRadius.all(Radius.circular(6.0))
            ),
        ),
          onTap: () {
            Router.push(context, Router.searchPage, '搜索笨啦灯');
          },
        )
      ]
    ),
  );
}