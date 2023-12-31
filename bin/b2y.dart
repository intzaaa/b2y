import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
// import 'package:prompts/prompts.dart';
import 'package:googleapis/youtube/v3.dart';
// import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:b2y/video.dart';

/// The `Static` class contains static constants and variables related to the Bilibili and YouTube APIs.
class Static {
  static const String bilibili = 'https://api.bilibili.com';
  static final Map<String, String> bilibiliHeaders = {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 Edg/115.0.1901.183',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'accept-language': 'zh',
    'cache-control': 'no-cache',
    'pragma': 'no-cache',
    'sec-ch-ua':
        '"Not/A)Brand";v="99", "Microsoft Edge";v="115", "Chromium";v="115"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'none',
    'sec-fetch-user': '?1',
    'upgrade-insecure-requests': '1',
    'cookie': bilibiliCookie,
    'referer': 'https://www.bilibili.com/'
  };
  static final String bilibiliCookie =
      Platform.environment['bilibili_cookie'] ?? '';
  static final int bilibiliMemberId =
      int.parse(Platform.environment['bilibili_mid'] ?? '473013658');
  static final String youtubeOAuthClientId =
      Platform.environment['youtube_oauth_client_id']!;
  static final String youtubeOAuthClientSecret =
      Platform.environment['youtube_oauth_client_secret']!;
  static final String youtubeOAuthRefreshToken =
      Platform.environment['youtube_oauth_refresh_token']!;
  static final String youtubeChannelId =
      Platform.environment['youtube_channel_id'] ?? 'UC7vRSbEDoaVf7uJY-IeCzVA';
  static final int youtubeDefaultCategoryId =
      int.parse(Platform.environment['youtubeDefaultCategoryId'] ?? '27');
}

void main(List<String> args) async {
  final videos =
      compareDiffence(await Bilibili().videoList, await Youtube().videoList);
  videos.forEach((element) async {
    final remoteFile = RemoteFile(Uri.parse(await element.url()));
    final file = await remoteFile.download();
  });
}

class RemoteFile {
  RemoteFile(this.uri);
  final Uri uri;

  Future<({Stream<List<int>> stream, int length})> get stream async {
    final http.Client client = http.Client();
    final res = await client.send(http.Request('GET', uri));
    return (stream: res.stream, length: res.contentLength ?? -1);
  }

  Future<File> download() async {
    final file = File(uri.path.split('/').last);
    await file.openWrite().addStream((await stream).stream);
    return file;
  }
}

class BilibiliVideo extends Video {
  BilibiliVideo(
      {required String id,
      required VideoSnippet snippet,
      required this.url,
      this.ps})
      : super(id: id, snippet: snippet);
  List<BilibiliVideo>? ps;
  Future<String> Function() url;
}

class Bilibili {
  Future<List<BilibiliVideo>> get videoList async {
    final http.Client client = http.Client();
    final Map res = jsonDecode((await client.get(
            Uri.parse(
                '${Static.bilibili}/x/space/wbi/arc/search?mid=${Static.bilibiliMemberId}'),
            headers: Static.bilibiliHeaders))
        .body);
    if (res['code'] == 0) {
      final List vlist = res['data']['list']['vlist'];
      for (var item in vlist) {
        Future<int> cid(bvid) async {
          return jsonDecode((await client.get(
                  Uri.parse(
                      'https://api.bilibili.com/x/player/pagelist?bvid=$bvid'),
                  headers: Static.bilibiliHeaders))
              .body)['data'][0]['cid'];
        }

        Future<String> playUrl(cid) async {
          final Map playData = jsonDecode((await client.get(
                  Uri.parse(
                      'https://api.bilibili.com/x/player/playurl?cid=$cid&bvid=$bvid&fnval=1&platform=html5&high_quality=1&qn=80'),
                  headers: Static.bilibiliHeaders))
              .body)['data'];
          return playData['durl'][0]['url'];
        }

        item['play_uri'] = playUrl;

        Future<List<Map>> pages(bvid) async {
          final List<Map> pages = jsonDecode((await client.get(
                  Uri.parse(
                      'https://api.bilibili.com/x/web-interface/view?bvid=$bvid'),
                  headers: Static.bilibiliHeaders))
              .body)['data']['pages'];
          for (var item in pages) {
            item['play_url'] = playUrl(item['cid']);
          }
          return pages;
        }

        item['pages'] = pages;
      }
      final List<BilibiliVideo> list = [];
      for (var item in vlist) {
        final video = BilibiliVideo(
            id: item['bvid'],
            snippet: VideoSnippet()
              ..title = item['title']
              ..description = item['description']
              ..categoryId = Static.youtubeDefaultCategoryId.toString(),
            url: item['play_uri'],
            ps: item['pages']);
        list.add(video);
      }
      return list;
    } else {
      throw jsonEncode(res);
    }
  }
}

class Youtube {
// Use the oauth2 code grant server flow functionality to
// get an authenticated and auto refreshing client.
  Future<AutoRefreshingAuthClient> _obtainCredentials() async {
    var client = http.Client();
    var id =
        ClientId(Static.youtubeOAuthClientId, Static.youtubeOAuthClientSecret);
    var credentials = AccessCredentials(
        AccessToken('Bearer', '', DateTime.now()),
        Static.youtubeOAuthRefreshToken, [
      'https://www.googleapis.com/auth/youtube',
      'https://www.googleapis.com/auth/youtube.force-ssl',
      'https://www.googleapis.com/auth/youtube.channel-memberships.creator',
      'https://www.googleapis.com/auth/youtubepartner',
      'https://www.googleapis.com/auth/youtube.readonly',
      'https://www.googleapis.com/auth/youtube.upload',
    ]);
    return autoRefreshingClient(id, credentials, client);
  }

  Future<List<Video>> get videoList async {
    final client = await _obtainCredentials();
    final yt = YouTubeApi(client);
    // https://developers.google.com/youtube/v3/docs/search/list#parameters
    final res =
        await yt.search.list(['snippet'], channelId: Static.youtubeChannelId);
    var items = res.items!.where((element) => element.id!.videoId != null);
    List<Video> list = [];
    for (var item in items) {
      list.add(Video(
          snippet: VideoSnippet()
            ..title = item.snippet!.title
            ..description = item.snippet!.description));
    }
    client.close();
    return list;
  }

  /// https://developers.google.com/youtube/v3/docs/videos/insert
  void uploadVideo(Stream<List<int>> stream, int length, String title,
      String description, int categoryId, String id) async {
    final client = await _obtainCredentials();
    final yt = YouTubeApi(client);
    final video = Video(
        snippet: VideoSnippet()
          ..title = title
          ..channelId = Static.youtubeChannelId
          ..description = '$description\n(DO NOT EDIT THIS LINE) ${id.hashCode}'
          ..categoryId = categoryId.toString());
    final media = Media(stream, length);
    await yt.videos.insert(video, ['snippet'], uploadMedia: media);
    client.close();
  }
}

List<BilibiliVideo> compareDiffence(
    List<BilibiliVideo> bilibiliVideoList, List<Video> youtubeVideoList) {
  return bilibiliVideoList.where((item) {
    return youtubeVideoList.contains(((element) {
      final String description = element.snippet!.description!;
      if (description.split('\n').last.contains(item.id.hashCode.toString())) {
        return false;
      } else {
        return true;
      }
    }));
  }).toList();
}
