import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:pod_player/pod_player.dart';
import 'package:pstube/data/models/models.dart';
import 'package:pstube/foundation/services.dart';
import 'package:pstube/ui/widgets/video_player_desktop/vid_player_mpv.dart';
import 'package:pstube/ui/widgets/video_player_mobile.dart';

class PlatformVideoPlayer extends StatelessWidget {
  const PlatformVideoPlayer({
    required this.videoData,
    required this.isCinemaMode,
    super.key,
  });

  final ValueNotifier<bool> isCinemaMode;
  final VideoData videoData;

  @override
  Widget build(BuildContext context) {
    // Get video-only streams (pure video, no audio)
    final videoonlyStreams = (videoData.videoStreams ?? BuiltList.from([]))
        .where(
          (p0) => (p0.videoOnly ?? false) &&
              // Filter out streams that contain audio codecs (not true video-only)
              !(p0.codec?.contains('mp4a') ?? false) &&
              !(p0.codec?.contains('opus') ?? false),
        )
        .toList();
    
    // Audio-only streams (pure audio, no video)
    final audioonlyStreams = (videoData.audioStreams ?? BuiltList.from([]))
        .where(
          (p0) => (p0.quality?.isEmpty ?? true) || p0.codec == 'opus',
        )
        .toList();

    // Muxed streams (combined video+audio) - fallback when video-only+audio-only unavailable
    final muxedStreams = (videoData.audioStreams ?? BuiltList.from([]))
        .where(
          (p0) => (p0.quality?.startsWith('muxed-') ?? false) && p0.url != null,
        )
        .toList();

    if (Constants.isMobileOrWeb) {
      return VideoPlayerMobile(
        defaultQuality: 360,
        resolutions: videoonlyStreams
            .map(
              (value) => VideoQalityUrls(
                quality: int.tryParse(
                      value.quality?.substring(0, value.quality!.length - 1) ?? '0',
                    ) ??
                    0,
                url: value.url.toString(),
              ),
            )
            .toList(),
      );
    } else {
      // Check if we have video-only + audio-only streams
      final hasVideoOnly = videoonlyStreams.isNotEmpty;
      final hasAudioOnly = audioonlyStreams.isNotEmpty;
      
      // Use muxed stream as fallback if video-only or audio-only is missing
      if (hasVideoOnly && hasAudioOnly) {
        // Use video-only + audio-only for best quality
        return VideoPlayerMpv(
          isCinemaMode: isCinemaMode,
          url: videoonlyStreams.first.url.toString(),
          audstreams: audioonlyStreams.asMap().map(
                (key, value) => MapEntry(
                  value.bitrate!,
                  value.url.toString(),
                ),
              ),
          resolutions: videoonlyStreams.asMap().map(
                (key, value) => MapEntry(
                  value.quality!,
                  value.url.toString(),
                ),
              ),
          handw: videoonlyStreams.asMap().map(
                (key, value) => MapEntry(
                  value.width!,
                  value.height!,
                ),
              ),
        );
      } else if (muxedStreams.isNotEmpty) {
        // Fall back to muxed stream (combined video+audio)
        final muxed = muxedStreams.first;
        return VideoPlayerMpv(
          isCinemaMode: isCinemaMode,
          url: muxed.url.toString(),
          audstreams: {},
          resolutions: {muxed.quality!: muxed.url.toString()},
          handw: {(muxed.height ?? 360): (muxed.width ?? 640)},
        );
      } else {
        // No playable streams available
        return Center(
          child: Text(
            'No playable video streams available',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      }
    }
  }
}
