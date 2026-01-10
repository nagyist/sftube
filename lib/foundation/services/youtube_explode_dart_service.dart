// ignore_for_file: avoid_classes_with_only_static_members, unnecessary_cast, unnecessary_type_check

import 'dart:async';
import 'package:built_collection/built_collection.dart';
import 'package:pstube/data/models/comment_data.dart';
import 'package:pstube/data/models/models.dart';
import 'package:pstube/data/models/video_data.dart';
import 'package:piped_api/piped_api.dart' as piped_api;
import 'package:piped_api/piped_api.dart' show SearchFilter;
import 'package:youtube_explode_dart/src/videos/video_id.dart' as yt_video_id;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_lib;

/// YouTubeExplode service for video data with streams
/// Used as primary source when Piped API is unavailable for video details
class YoutubeExplodeService {
  static yt_lib.YoutubeExplode? _yt;

  static yt_lib.YoutubeExplode get yt {
    _yt ??= yt_lib.YoutubeExplode();
    return _yt!;
  }

  /// Reset the client (useful when network issues occur)
  static void resetClient() {
    _yt?.close();
    _yt = null;
  }

  /// Get video data with streams (primary method)
  /// Falls back to null if YouTubeExplode fails
  static Future<VideoData?> getVideoData(VideoId pstubeVideoId) async {
    try {
      // Create YouTubeExplode VideoId from pstube VideoId
      final ytVideoId = yt_video_id.VideoId(pstubeVideoId.value);
      final video = await yt.videos.get(ytVideoId.value);
      final manifest = await yt.videos.streamsClient.getManifest(ytVideoId.value);
      final channel = await yt.channels.get(video.channelId.value);

      // Audio-only streams (pure audio, no video track)
      // Check if codec only contains audio codec (no video codec like avc)
      final audioOnlyStreams = manifest.audio
          .where((a) {
            final codecs = a.codec.parameters['codecs'] as String?;
            if (codecs == null) return false;
            // Audio-only if it doesn't contain video codec (avc, vp9, vp8)
            return !codecs.contains('avc') && 
                   !codecs.contains('vp9') && 
                   !codecs.contains('vp8');
          })
          .map(
            (a) => piped_api.Stream((b) => b
              ..url = a.url.toString()
              ..bitrate = a.bitrate.bitsPerSecond
              ..mimeType = a.container.name
              ..codec = (a.codec.parameters['codecs'] as String?) ?? ''
              ..quality = null
              ..videoOnly = false),
          )
          .toBuiltList();

      // Video-only streams (pure video, no audio track)
      final videoOnlyStreams = manifest.video
          .where((v) => v.videoQualityLabel != '144p')
          .map(
            (v) => piped_api.Stream((b) => b
              ..url = v.url.toString()
              ..bitrate = v.bitrate.bitsPerSecond
              ..mimeType = v.container.name
              ..codec = v.codec.parameters['codecs'] ?? ''
              ..quality = v.videoQualityLabel
              ..width = v.videoResolution.width
              ..height = v.videoResolution.height
              ..fps = v.framerate.framesPerSecond.toInt()
              ..videoOnly = true),
          )
          .toBuiltList();

      // Muxed streams (combined video+audio) - stored with special quality
      // videoOnly = false so they appear in "Video + Audio" section
      final muxedStreams = manifest.muxed.map((m) {
        final quality = m.videoQualityLabel;
        final height = int.tryParse(quality.replaceAll('p', '')) ?? 360;
        return piped_api.Stream((b) => b
          ..url = m.url.toString()
          ..bitrate = m.bitrate.bitsPerSecond
          ..mimeType = m.container.name
          ..codec = ''
          ..quality = 'muxed-$quality'  // Special marker for muxed
          ..width = (height * 16 / 9).toInt()
          ..height = height
          ..fps = null
          ..videoOnly = false);  // Not video-only, it's combined
      }).toBuiltList();

      return VideoData(
        thumbnails: Thumbnails(videoId: pstubeVideoId.value),
        title: video.title,
        id: pstubeVideoId,
        duration: video.duration?.inSeconds,
        durationString: video.duration?.toString(),
        uploaded: video.uploadDate?.millisecondsSinceEpoch,
        uploadDate: video.uploadDate?.toString(),
        uploaderAvatar: channel.logoUrl,
        uploader: video.author,
        uploaderId: UploaderId.addPrefix('/channel/${video.channelId.value}'),
        uploaderVerified: false,
        views: video.engagement.viewCount,
        relatedStreams: null,
        // Combine audio-only and muxed streams
        // Muxed streams have quality starting with "muxed-" 
        audioStreams: audioOnlyStreams + muxedStreams,
        videoStreams: videoOnlyStreams,
        description: video.description,
        likes: video.engagement.likeCount,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get video info only (no streams) for list display
  static Future<VideoData?> getVideoInfo(VideoId pstubeVideoId) async {
    try {
      // Create YouTubeExplode VideoId from pstube VideoId
      final ytVideoId = yt_video_id.VideoId(pstubeVideoId.value);
      final video = await yt.videos.get(ytVideoId.value);

      return VideoData(
        thumbnails: Thumbnails(videoId: pstubeVideoId.value),
        title: video.title,
        id: pstubeVideoId,
        duration: video.duration?.inSeconds,
        durationString: video.duration?.toString(),
        uploaded: null,
        uploadDate: video.uploadDate?.toString(),
        uploaderAvatar: null,
        uploader: video.author,
        uploaderId: UploaderId.addPrefix('/channel/${video.channelId.value}'),
        uploaderVerified: false,
        views: video.engagement.viewCount,
        relatedStreams: null,
        audioStreams: null,
        videoStreams: null,
        description: null,
        likes: null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get comments for a video
  static Future<List<CommentData>> getComments(String videoId) async {
    try {
      final ytVideoId = yt_video_id.VideoId(videoId);
      final video = await yt.videos.get(ytVideoId.value);
      final commentsList = await yt.videos.commentsClient.getComments(video);
      
      if (commentsList == null || commentsList.isEmpty) {
        return [];
      }

      return commentsList.map((c) => CommentData(
        commentorUrl: c.channelId.value,
        isVerified: false,
        author: c.author,
        commentText: c.text,
        commentedTime: c.publishedTime,
        likeCount: c.likeCount,
        hearted: c.isHearted,
        replies: c.replyCount,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Search videos
  // ignore: always_specify_types
  static Future<List<VideoData>> searchVideos(String query, {SearchFilter? filter}) async {
    try {
      // Add timeout to prevent hanging
      final results = await yt.search.search(query).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Search timed out'),
      );
      
      // Filter based on type if filter is provided
      if (filter == SearchFilter.channels) {
        // Channels not supported, return empty
        return [];
      }
      
      // Only include Video results (filter out channels/playlists)
      // ignore: always_specify_types
      final videoResults = results.where((r) => r is yt_lib.Video).cast<yt_lib.Video>().toList();
      
      return videoResults.map((video) => VideoData(
        thumbnails: Thumbnails(videoId: video.id.value),
        title: video.title,
        id: VideoId(video.id.value),
        duration: video.duration?.inSeconds,
        durationString: video.duration?.toString(),
        uploaded: null,
        uploadDate: video.uploadDate?.toString(),
        uploaderAvatar: null,
        uploader: video.author,
        uploaderId: UploaderId.addPrefix('/channel/${video.channelId.value}'),
        uploaderVerified: false,
        views: video.engagement.viewCount,
        relatedStreams: null,
        audioStreams: null,
        videoStreams: null,
        description: null,
        likes: null,
      )).toList();
    } on TimeoutException {
      // Reset client on timeout to prevent future hangs
      resetClient();
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get stream URL for direct playback/download
  static Future<String?> getStreamUrl(VideoId pstubeVideoId, {bool audioOnly = false}) async {
    try {
      final ytVideoId = yt_video_id.VideoId(pstubeVideoId.value);
      final manifest = await yt.videos.streamsClient.getManifest(ytVideoId.value);
      
      if (audioOnly) {
        final audio = manifest.audio.first;
        return audio.url.toString();
      } else {
        // Prefer muxed stream for combined playback
        if (manifest.muxed.isNotEmpty) {
          return manifest.muxed.first.url.toString();
        }
        final video = manifest.video.first;
        return video.url.toString();
      }
    } catch (e) {
      return null;
    }
  }

  /// Close the YouTubeExplode client
  static void close() {
    _yt?.close();
    _yt = null;
  }
}
