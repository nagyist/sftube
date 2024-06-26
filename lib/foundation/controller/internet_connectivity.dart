import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline, restored }

class InternetConnectivity {
  static final StreamController<NetworkStatus> _networkController =
      StreamController.broadcast();

  static Stream<NetworkStatus> get networkStream => _networkController.stream;

  static NetworkStatus _status = NetworkStatus.online;
  static NetworkStatus get status => _status;

  static Future<void> networkStatusService() async {
    Connectivity().onConnectivityChanged.listen((status) async {
      if (!status.contains(ConnectivityResult.none)) {
        _networkController.add(NetworkStatus.restored);
        await Future<dynamic>.delayed(const Duration(seconds: 2));
        if (!status.contains(ConnectivityResult.none)) {
          _networkController.add(NetworkStatus.online);
        }
      } else {
        _networkController.add(NetworkStatus.offline);
      }
    });
    _networkController.stream
        .listen((dynamic event) => _status = event as NetworkStatus);
    if ((await Connectivity().checkConnectivity())
        .contains(ConnectivityResult.none)) {
      _networkController.add(NetworkStatus.offline);
    }
  }

  void dispose() {
    _networkController.close();
  }
}
