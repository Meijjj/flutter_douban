import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_douban/http/API.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_douban/router.dart';
import 'package:flutter_douban/bean/subject_entity.dart';
import 'package:flutter_douban/pages/movie/title_widget.dart';
import 'package:flutter_douban/pages/movie/today_playe_movie_widget.dart';
import 'package:flutter_douban/repository/movie_repository.dart';
import 'package:flutter_douban/pages/movie/hot_soon_tab_bar.dart';
import 'package:flutter_douban/widgets/subject_mark_image_widget.dart';
import 'package:flutter_douban/widgets/rating_bar.dart';
import 'package:flutter_douban/constant/color_constant.dart';
import 'package:flutter_douban/constant/constant.dart';
import 'package:flutter_douban/widgets/image/cache_img_radius.dart';
import 'package:flutter_douban/widgets/item_count_title.dart';
import 'package:flutter_douban/pages/movie/top_item_widget.dart';
import 'package:flutter_douban/bean/top_item_bean.dart';

typedef OnTab = void Function();
class MoviePage extends StatefulWidget {
  MoviePage({ Key key }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _MoviePageState();
  }
}

class _MoviePageState extends State<MoviePage> with AutomaticKeepAliveClientMixin {
  Widget titleWidget, hotSoonTabBarPadding;
  HotSoonTabBar hotSoonTabBar;
  List<Subject> hotShowBeans = List(); //影院热映
  List<Subject> comingSoonBeans = List(); //即将上映
  List<Subject> hotBeans = List(); //豆瓣榜单
  List<SubjectEntity> weeklyBeans = List(); //一周口碑电影榜
  List<Subject> top250Beans = List(); //Top250
  var hotChildAspectRatio;
  var comingSoonChildAspectRatio;
  int selectIndex = 0; //选中的是热映、即将上映
  var itemW;
  var imgSize;
  List<String> todayUrls = [];
  TopItemBean weeklyTopBean, weeklyHotBean, weeklyTop250Bean;
  Color weeklyTopColor, weeklyHotColor, weeklyTop250Color;
  Color todayPlayBg = Color.fromARGB(255, 47, 22, 74);

  @override
  void initState() {
    super.initState();
    titleWidget = Padding(padding: EdgeInsets.only(top: 10.0), child: TitleWidget());

    hotSoonTabBar = HotSoonTabBar(
      onTabCallBack: (index) {
        setState(() {
          selectIndex = index;
        });
      }
    );

    hotSoonTabBarPadding = Padding(
      padding: EdgeInsets.only(top: 35.0, bottom: 15.0),
      child: hotSoonTabBar,
    );
    requestAPI();
  }

  bool loading = true;
  MovieRepository repository = MovieRepository();
  void requestAPI() async {
    Future(() => (repository.requestAPI())).then((value) {
      todayUrls = value.todayUrls;
      hotShowBeans = value.hotShowBeans;    // 影院热映
      comingSoonBeans = value.comingSoonBeans;  // 即将上映
      hotBeans = value.hotBeans;  // 豆瓣热门
      weeklyBeans = value.weeklyBeans;
      weeklyTopBean = value.weeklyTopBean;  // 一周榜单
      hotSoonTabBar.setCount(hotShowBeans);
      hotSoonTabBar.setComingSoon(comingSoonBeans);
      setState(() {
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (itemW == null || imgSize <= 0) {
      MediaQuery.of(context);
      var w = MediaQuery.of(context).size.width;
      imgSize = w / 5 * 3;
      itemW = (w - 30.0 - 20.0) / 3;
      hotChildAspectRatio = (377.0 / 674.0);
      comingSoonChildAspectRatio = (377.0 / 742.0);
    }
    return Stack(
      children: <Widget>[
        containerBody()
      ],
    );
  }

  Widget containerBody() {
    return Padding(
      padding: EdgeInsets.only(left: 15.0, right: 15.0),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        slivers: <Widget>[
          SliverToBoxAdapter(child: titleWidget),   // 包裹成为slivers
          SliverToBoxAdapter(child: Padding(
            child: TodayPlayMovieWidget(todayUrls, backgroundColor: todayPlayBg), padding: EdgeInsets.only(top: 22.0),
          )),
          SliverToBoxAdapter(child: hotSoonTabBarPadding),
          SliverGrid(
            delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
              var hotMovieBean;
              var comingSoonBean;
              if (hotShowBeans.length > 0) {
                hotMovieBean = hotShowBeans[index];
              }
              if (comingSoonBeans.length > 0) {
                comingSoonBean = comingSoonBeans[index];
              }
              return Stack(
                children: <Widget>[
                  Offstage(     // 影院热映
                    child: _getHotMovieItem(hotMovieBean, itemW),
                    offstage: !(selectIndex == 0 && hotShowBeans != null && hotShowBeans.length > 0),
                  ),
                  Offstage(   // 即将上映
                    child: _getComingSoonItem(comingSoonBean, itemW),
                    offstage: !(selectIndex == 1 && comingSoonBeans != null && comingSoonBeans.length > 0),
                  )
                ]
              );
            }, childCount: math.min(_getChildCount(), 6)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 0.0,
                childAspectRatio: _getRadio()
            )),
          getCommonImg(Constant.IMG_TMP1, () {
            Router.pushNoParams(context, "http://www.flutterall.com");
          }),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 20.0, bottom: 15.0),
              child: ItemCountTitle('豆瓣热门', fontSize: 13.0, count: hotBeans == null ? 0 : hotBeans.length),
            ),
          ),
          getCommonSliverGrid(hotBeans),
          getCommonImg(Constant.IMG_TMP2, null),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 20.0, bottom: 15.0),
              child: ItemCountTitle('豆瓣榜单', count: weeklyBeans == null ? 0 : weeklyBeans.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: imgSize,
              child: ListView(
                children: <Widget>[
                  TopItemWidget(title: '一周口碑电影榜', bean: weeklyTopBean, partColor: weeklyTopColor)
                ],
                scrollDirection: Axis.horizontal,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _getHotMovieItem(Subject hotMovieBean, var itemW) {    // 影院热映
    if (hotMovieBean == null) {
      return Container();
    }
    return GestureDetector(
      child: Container(
        child: Column(
          children: <Widget>[
            SubjectMarkImageWidget(hotMovieBean.images.large, width: itemW,),
            Padding(
              padding: EdgeInsets.only(top: 5.0),
              child: Container(
                width: double.infinity,
                child: Text(
                  hotMovieBean.title,
                  softWrap: false,
                  overflow: TextOverflow.fade,    // 多出的文字隐藏
                  style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            RatingBar(hotMovieBean.rating.average, size: 12.0)
          ],
        ),
      ),
      onTap: () {
        Router.push(context, Router.detailPage, hotMovieBean.id);
      },
    );
  }

  Widget _getComingSoonItem(Subject comingSoonBean, var itemW) {      // 即将上映
    if (comingSoonBean == null) {
      return Container();
    }

    String mainland_pubdate = comingSoonBean.mainland_pubdate;
    mainland_pubdate = mainland_pubdate.substring(5, mainland_pubdate.length);
    mainland_pubdate = mainland_pubdate.replaceFirst(RegExp(r'-'), '月') + '日';
    return GestureDetector(
      child: Container(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SubjectMarkImageWidget(comingSoonBean.images.large, width: itemW),
            Padding(
              padding: EdgeInsets.only(top: 5.0, bottom: 5.0),
              child: Container(
                width: double.infinity,
                child: Text(
                  comingSoonBean.title,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Container(
              decoration: const ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: ColorConstant.colorRed277), borderRadius: BorderRadius.all(Radius.circular(2.0))
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(left: 5.0, right: 5.0),
                child: Text(mainland_pubdate, style: TextStyle(fontSize: 8.0, color: ColorConstant.colorRed277))),
              )
          ]
        ),
      ),
      onTap: () {
        Router.push(context, Router.detailPage, comingSoonBean.id);
      },
    );
  }

  getCommonImg(String url, OnTab onTab) {    // 背景r角图片
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: 15.0),
        child: CacheImgRadius(imgUrl: url, radius: 5.0, onTab: (){ if(onTab != null) { onTab(); } }),
      ),
    );
  }

  int _getChildCount() {    // 显示元素数量
    if (selectIndex == 0) {
      return hotShowBeans.length;
    } else {
      return comingSoonBeans.length;
    }
  }

  double _getRadio() {    // 显示的长宽比例
    if (selectIndex == 0) {
      return hotChildAspectRatio;
    } else {
      return comingSoonChildAspectRatio;
    }
  }

  SliverGrid getCommonSliverGrid(List<Subject> hotBeans) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        return _getHotMovieItem(hotBeans[index], itemW);
      }, childCount: math.min(hotBeans.length, 6)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 0.0,
            childAspectRatio: hotChildAspectRatio
        )
    );
  }

  @override
  bool get wantKeepAlive => true;
}