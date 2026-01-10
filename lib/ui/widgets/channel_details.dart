import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libadwaita/libadwaita.dart';
import 'package:piped_api/piped_api.dart';
import 'package:pstube/foundation/extensions/extensions.dart';
import 'package:pstube/foundation/services/piped_instances.dart';
import 'package:pstube/ui/screens/screens.dart';
import 'package:pstube/ui/widgets/widgets.dart';

class ChannelDetails extends HookConsumerWidget {
  const ChannelDetails({
    required this.channelId,
    super.key,
    this.textColor,
    this.isOnVideo = false,
  });

  final String channelId;
  final bool isOnVideo;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = isOnVideo ? 40 : 60;
    final api = ref.watch(unauthenticatedApiProvider);
    final channelData = useFuture<Response<ChannelInfo>>(
      useMemoized(
        () => api.channelInfoId(
          channelId: channelId,
        ),
        [channelId],
      ),
    ).data?.data;

    return GestureDetector(
      onTap: isOnVideo && channelData != null
          ? () => context.pushPage(
                ChannelScreen(
                  channelId: channelId,
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            ChannelLogo(
              channel: channelData,
              size: size.toDouble(),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelData?.name ?? '',
                    overflow: TextOverflow.clip,
                    style: context.textTheme.headlineMedium,
                  ),
                  Text(
                    channelData != null
                        ? channelData.subscriberCount == null ||
                                channelData.subscriberCount == -1
                            ? context.locals.hidden
                            : '${channelData.subscriberCount!.formatNumber} '
                                '${context.locals.subscribers}'
                        : '',
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            AdwButton.flat(
              onPressed: () {},
              child: Text(
                'SUBSCRIBE',
                style: TextStyle(
                  color:
                      context.theme.primaryColor.brightenReverse(context, 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
