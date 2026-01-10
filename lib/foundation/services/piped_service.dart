import 'package:built_collection/built_collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:piped_api/piped_api.dart';
import 'package:pstube/data/models/channel_data.dart';
import 'package:pstube/data/models/comment_data.dart';
import 'package:pstube/data/models/models.dart';
import 'package:pstube/data/models/playlist_data.dart';
import 'package:pstube/data/models/search_data.dart';
import 'package:pstube/states/region/provider.dart';
import 'package:pstube/foundation/services/piped_instances.dart';
import 'package:pstube/foundation/services/youtube_explode_dart_service.dart';

final pipedServiceProvider = Provider<PipedService>((ref) {
  final api = ref.watch(unauthenticatedApiProvider);
  return PipedService(api: api, ref: ref);
});
final trendingVideosProvider = FutureProvider((ref) {
  final pipedService = ref.watch(pipedServiceProvider);
  return pipedService.getTrending();
});

class PipedService {
  PipedService({required this.api, required this.ref});

  final Ref ref;
  final UnauthenticatedApi api;

  Future<ChannelData?> channelInfo(UploaderId uploaderId) async {
    // Try YouTubeExplode first (more reliable)
    final ytData = await YoutubeExplodeService.getVideoInfo(VideoId('/watch?v=dummy'));
    if (ytData != null) {
      // YouTubeExplode doesn't have channel info, fall back to Piped
    }

    // Fallback to Piped
    try {
      final info = await api.channelInfoId(channelId: uploaderId.value);
      if (info.data == null) return null;
      return ChannelData.fromChannelInfo(channelInfo: info.data!);
    } catch (e) {
      return null;
    }
  }

  Future<BuiltList<VideoData>?> getTrending() async {
    // Piped trending works, use it directly
    final trending = await api.trending(
      region: ref.watch(regionProvider),
    );

    if (trending.data == null) return null;
    final data = trending.data!
        .map(
          VideoData.fromStreamItem,
        )
        .toBuiltList();

    return data;
  }

  Future<StreamList<VideoData>?> channelNextPage({
    required UploaderId uploaderId,
    required String nextpage,
  }) async {
    final commentsPage = (await api.channelNextPage(
      nextpage: nextpage,
      channelId: uploaderId.value,
    ))
        .data;

    if (commentsPage?.relatedStreams == null) return null;

    final comments = commentsPage!.relatedStreams!
        .map(
          VideoData.fromStreamItem,
        )
        .toBuiltList();

    return StreamList(
      streams: comments,
      nextpage: commentsPage.nextpage,
    );
  }

  Future<VideoData?> getVideoData(VideoId videoId) async {
    // Try YouTubeExplode first (more reliable for streams)
    final ytData = await YoutubeExplodeService.getVideoData(videoId);
    if (ytData != null) return ytData;

    // Fallback to Piped
    try {
      final data = (await api.streamInfo(
        videoId: videoId.value,
      ))
          .data;

      if (data == null) return null;

      return VideoData.fromVideoInfo(
        data,
        videoId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<StreamList<CommentData>?> comments({required String videoId}) async {
    // Use Piped for comments (YouTubeExplode comments are broken since v2.2.0)
    try {
      final commentsPage = (await api.comments(
        videoId: videoId,
      ))
          .data;

      if (commentsPage?.comments == null) return null;

      final comments = commentsPage!.comments!
          .map(
            CommentData.fromComment,
          )
          .toBuiltList();

      return StreamList(
        streams: comments,
        nextpage: commentsPage.nextpage,
      );
    } catch (e) {
      return null;
    }
  }

  Future<StreamList<CommentData>?> commentsNextPage({
    required String videoId,
    required String nextpage,
  }) async {
    final commentsPage = (await api.commentsNextPage(
      nextpage: nextpage,
      videoId: videoId,
    ))
        .data;

    if (commentsPage?.comments == null) return null;

    final comments = commentsPage!.comments!
        .map(
          CommentData.fromComment,
        )
        .toBuiltList();

    return StreamList(
      streams: comments,
      nextpage: commentsPage.nextpage,
    );
  }

  Future<StreamList<SearchData>?> search({
    required String query,
    required SearchFilter filter,
  }) async {
    // Try YouTubeExplode first for video/channel search
    if (filter == SearchFilter.videos || filter == SearchFilter.channels) {
      try {
        final ytResults = await YoutubeExplodeService.searchVideos(
          query,
          filter: filter,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            YoutubeExplodeService.resetClient();
            return <VideoData>[];
          },
        );
        if (ytResults.isNotEmpty) {
          final searchData = ytResults.map((e) => SearchData(data: e)).toBuiltList();
          return StreamList(streams: searchData, nextpage: null);
        }
      } catch (e) {
        // YouTubeExplode failed, fall through to Piped
      }
    }

    // Fallback to Piped
    try {
      final data = (await api.search(
        q: query,
        filter: filter,
      ))
          .data;

      if (data == null) return null;

      // Convert SearchItem to appropriate data types
      final results = data.items!.map((e) {
        final itemData = e.data;
        if (itemData is StreamItem) {
          // Convert to VideoData
          return SearchData(data: VideoData.fromStreamItem(itemData));
        } else if (itemData is ChannelItem) {
          // Convert to ChannelData
          return SearchData(data: ChannelData.fromChannelItem(itemData));
        } else if (itemData is PlaylistItem) {
          // Keep as PlaylistData
          return SearchData(data: PlaylistData.fromPlaylistItem(searchItem: itemData));
        }
        // Fallback for unknown types
        return SearchData(data: itemData);
      }).toBuiltList();

      return StreamList(
        streams: results,
        nextpage: data.nextpage,
      );
    } catch (e) {
      return null;
    }
  }

  Future<StreamList<SearchData>?> searchNextPage({
    required String nextpage,
    required String query,
    required SearchFilter filter,
  }) async {
    final searchPage = (await api.searchNextPage(
      nextpage: nextpage,
      q: query,
      filter: filter,
    ))
        .data;

    if (searchPage?.items == null) return null;

    // Convert SearchItem to appropriate data types
    final results = searchPage!.items!
        .map((e) {
          final itemData = e.data;
          if (itemData is StreamItem) {
            // Convert to VideoData
            return SearchData(data: VideoData.fromStreamItem(itemData));
          } else if (itemData is ChannelItem) {
            // Convert to ChannelData
            return SearchData(data: ChannelData.fromChannelItem(itemData));
          } else if (itemData is PlaylistItem) {
            // Keep as PlaylistData
            return SearchData(data: PlaylistData.fromPlaylistItem(searchItem: itemData));
          }
          // Fallback for unknown types
          return SearchData(data: itemData);
        })
        .toBuiltList();

    return StreamList(
      streams: results,
      nextpage: searchPage.nextpage,
    );
  }
}
