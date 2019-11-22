import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_douban/pages/containers_page.dart';
import 'package:flutter_douban/pages/search/search_page.dart';
import 'package:flutter_douban/pages/videos_play_page.dart';   // 视频图片预览

class Router {
  static const homePage = 'app//';
  static const detailPage = 'app://DetailPage';
  static const searchPage = 'app://SearchPage';
  static const playListPage = 'app://VideosPlayPage';

  Widget _getPage(String url, dynamic params) {
    if (url.startsWith('https://') || url.startsWith('http://')) {
      print('https');
    } else {
      switch (url) {
        case homePage:
          return ContainersPage();
        case searchPage:
          return SearchPage(searchHintContent: params);
        case playListPage:
          return VideoPlayPage(params);
      }
    }
    return null;
  }

  Router.pushNoParams(BuildContext context, String url) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return _getPage(url, null);
    }));
  }

  Router.push(BuildContext context, String url, dynamic params) {
    Navigator.push(context, MaterialPageRoute(builder:(context) {
      return _getPage(url, params);
    }));
  }

}

