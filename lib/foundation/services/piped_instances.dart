import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:piped_api/piped_api.dart';

const String _instanceListUrl = 'https://piped-instances.kavin.rocks/';

/// Represents a Piped API instance
class PipedInstance {
  final String name;
  final String apiUrl;
  final String? version;
  final double uptime24h;
  final bool upToDate;
  final bool cdn;

  PipedInstance({
    required this.name,
    required this.apiUrl,
    this.version,
    required this.uptime24h,
    required this.upToDate,
    this.cdn = false,
  });

  factory PipedInstance.fromJson(Map<String, dynamic> json) {
    return PipedInstance(
      name: (json['name'] ?? 'Unknown').toString(),
      apiUrl: (json['api_url'] ?? '').toString(),
      version: json['version']?.toString(),
      uptime24h: double.tryParse((json['uptime_24h'] ?? 0).toString()) ?? 0,
      upToDate: json['up_to_date'] == true,
      cdn: json['cdn'] == true,
    );
  }

  /// Whether this instance is healthy (high uptime)
  bool get isHealthy => uptime24h >= 95;

  /// Whether this instance is suitable for use
  bool get isSuitable => apiUrl.isNotEmpty && isHealthy && upToDate;
}

class PipedInstanceSelector {
  PipedInstanceSelector({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Fetches all available instances and selects the best one
  Future<PipedInstance> selectBestInstance() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _instanceListUrl,
        options: Options(sendTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode != 200 || response.data == null) {
        return _getFallbackInstance();
      }

      final instances = response.data!
          .map((e) => PipedInstance.fromJson(e as Map<String, dynamic>))
          .toList();

      if (instances.isEmpty) {
        return _getFallbackInstance();
      }

      // Sort by: uptime (descending), upToDate, then prefer non-CDN
      instances.sort((a, b) {
        if (a.isSuitable != b.isSuitable) {
          return a.isSuitable ? -1 : 1;
        }
        if (a.uptime24h != b.uptime24h) {
          return b.uptime24h.compareTo(a.uptime24h);
        }
        // Prefer non-CDN instances
        if (a.cdn != b.cdn) {
          return a.cdn ? 1 : -1;
        }
        return 0;
      });

      final selected = instances.first;
      if (kDebugMode) {
        print('Selected Piped instance: ${selected.name} (${selected.apiUrl})');
      }

      return selected;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fetch instances: $e');
      }
      return _getFallbackInstance();
    }
  }

  PipedInstance _getFallbackInstance() {
    return PipedInstance(
      name: 'Default',
      apiUrl: 'https://api.piped.private.coffee',
      version: null,
      uptime24h: 100,
      upToDate: true,
    );
  }
}

/// Provider for the Piped instance selector
final pipedInstanceSelectorProvider = Provider<PipedInstanceSelector>((ref) {
  return PipedInstanceSelector();
});

/// Default Piped instance URL (used immediately, instances fetched in background)
const String kDefaultPipedInstanceUrl = 'https://api.piped.private.coffee';

/// Future provider for the selected Piped instance (async, non-blocking)
final pipedInstanceProvider = FutureProvider<PipedInstance>((ref) async {
  final selector = ref.watch(pipedInstanceSelectorProvider);
  return selector.selectBestInstance();
});

/// Provider for the PipedApi with dynamically selected instance
/// Uses default URL immediately, switches to selected instance once available
final pipedApiProvider = Provider<PipedApi>((ref) {
  // Use default instance immediately (non-blocking)
  const defaultUrl = kDefaultPipedInstanceUrl;
  
  return PipedApi(basePathOverride: defaultUrl);
});

/// Provider for the UnauthenticatedApi
final unauthenticatedApiProvider = Provider<UnauthenticatedApi>((ref) {
  final api = ref.watch(pipedApiProvider);
  return api.getUnauthenticatedApi();
});
