import 'package:built_collection/built_collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pstube/data/models/channel_data.dart';
import 'package:pstube/data/models/models.dart';
import 'package:pstube/foundation/services/piped_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final channelProvider =
    ChangeNotifierProvider.autoDispose<ChannelNotifierProvider>((ref) {
  final api = ref.watch(pipedServiceProvider);
  final yt = YoutubeExplode();

  return ChannelNotifierProvider(ref, api, yt);
});

class ChannelNotifierProvider extends ChangeNotifier {
  ChannelNotifierProvider(this.ref, this.api, this.yt);

  final Ref ref;
  final PipedService api;
  final YoutubeExplode yt;

  bool isLoading = true;
  UploaderId? uploaderId;
  ChannelData? channelData;
  ChannelAbout? channelInfo;

  StreamList<VideoData>? _videosList;
  BuiltList<VideoData>? get videos => _videosList?.streams;

  @override
  void dispose() {
    yt.close();
    super.dispose();
  }

  Future<void> loadChannelData(String channelId) async {
    channelData = null;

    channelData = await api.channelInfo(
      UploaderId(channelId),
    );
    _videosList = channelData?.videos;
    notifyListeners();
  }

  Future<void> loadAboutPage(String channelId) async {
    try {
      // Note: YouTubeExplode's getAboutPage may fail for some channels
      channelInfo = await yt.channels.getAboutPage(channelId);
    } catch (e) {
      // Fallback to null if about page fails
      channelInfo = null;
    }
    notifyListeners();
  }

  Future<void> videosNextPage() async {
    if (!(_videosList?.hasNextpage ?? true) || isLoading) return;

    isLoading = true;
    notifyListeners();

    final nextPage = await api.channelNextPage(
      nextpage: _videosList!.nextpage!,
      uploaderId: uploaderId!,
    );

    if (nextPage?.streams == null) {
      return;
    }

    _videosList = _videosList!.rebuild(nextPage!.streams);
    isLoading = false;
    notifyListeners();
  }
}
