import 'dart:math' as math;
import 'package:flutter_douban/bean/subject_entity.dart';
import 'package:flutter_douban/http/http_request.dart';
import 'package:flutter_douban/http/API.dart';
import 'package:flutter_douban/http/mock_request.dart';
import 'package:flutter_douban/constant/cache_key.dart';
import 'package:flutter_douban/bean/top_item_bean.dart';
import 'package:flutter_douban/util/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class MovieRepository {
  var _request;
  List<Subject> hotShowBeans; //影院热映
  List<Subject> comingSoonBeans; //即将上映
  List<Subject> hotBeans; //豆瓣榜单
  List<SubjectEntity> weeklyBeans; //一周口碑电影榜
  List<Subject> top250Beans; //Top250
  List<String> todayUrls;
  TopItemBean weeklyTopBean, weeklyHotBean, weeklyTop250Bean;
  Color weeklyTopColor, weeklyHotColor, weeklyTop250Color, todayPlayBg;

  MovieRepository(
      {this.hotShowBeans,
        this.comingSoonBeans,
        this.hotBeans,
        this.weeklyBeans,
        this.top250Beans,
        this.todayUrls,
        this.weeklyTopBean,
        this.weeklyHotBean,
        this.weeklyTop250Bean,
        this.weeklyTopColor,
        this.weeklyHotColor,
        this.weeklyTop250Color,
        this.todayPlayBg});

  Future<MovieRepository> requestAPI() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool useNetData = prefs.getBool(CacheKey.USE_NET_DATA) ?? true;
    if (useNetData) {
      _request = HttpRequest(API.BASE_URL);
    } else {
      _request = MockRequest();
    }

    // 影院热映
    var result = await _request.get(API.IN_THEATERS);
    var resultList = result['subjects'];
    hotShowBeans = resultList.map<Subject>((item) => Subject.fromMap(item)).toList();

    // 即将上映
    result = await _request.get(API.COMING_SOON);
    resultList = result['subjects'];
    comingSoonBeans = resultList.map<Subject>((item) => Subject.fromMap(item)).toList();

    // 豆瓣热门
    hotBeans = resultList.map<Subject>((item) => Subject.fromMap(item)).toList();

    // 今日可播放电影
    int start = math.Random().nextInt(220);
    start = math.Random().nextInt(220);
    if (useNetData) {
      result = await _request.get(API.TOP_250 + '?start=$start&count=7&apikey=0b2bdeda43b5688921839c8ecb20399b');
    } else {
      result = await _request.get(API.TOP_250);
    }
    resultList = result['subjects'];
    List<Subject> beans = resultList.map<Subject>((item) => Subject.fromMap(item)).toList();
    todayUrls = [];
    todayUrls.add(beans[0].images.medium);
    todayUrls.add(beans[1].images.medium);
    todayUrls.add(beans[2].images.medium);

    // 一周热门电影榜
    weeklyHotBean = TopItemBean.convertHotBeans(hotBeans);
    var paletteGenerator = await PaletteGenerator.fromImageProvider(NetworkImage(hotBeans[0].images.medium));
    if (paletteGenerator != null && paletteGenerator.colors.isNotEmpty) {
      weeklyHotColor = (paletteGenerator.colors.toList()[0]);
    }

    // 一周榜单
    result = await _request.get(API.WEEKLY);
    resultList = result['subjects'];
    weeklyBeans = resultList.map<SubjectEntity>((item) => SubjectEntity.fromMap(item)).toList();
    weeklyTopBean = TopItemBean.convertWeeklyBeans(weeklyBeans);
    paletteGenerator = await PaletteGenerator.fromImageProvider(NetworkImage(weeklyBeans[0].subject.images.medium));
    if (paletteGenerator != null && paletteGenerator.colors.isNotEmpty) {
      weeklyTopColor = (paletteGenerator.colors.toList()[0]);
    }

    return MovieRepository(
      hotShowBeans: hotShowBeans,
      comingSoonBeans: comingSoonBeans,
      hotBeans: hotBeans,
      todayUrls: todayUrls,
      weeklyBeans: weeklyBeans,
      weeklyTopBean: weeklyTopBean,
    );
  }
}