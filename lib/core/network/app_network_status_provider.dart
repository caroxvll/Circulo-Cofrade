import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';
import 'app_network_status.dart';

final appNetworkStatusProvider =
    NotifierProvider<AppNetworkStatusNotifier, AppNetworkStatus>(
  AppNetworkStatusNotifier.new,
);

class AppNetworkStatusNotifier extends Notifier<AppNetworkStatus> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _poll;
  var _probeGen = 0;
  var _misses = 0;

  @override
  AppNetworkStatus build() {
    ref.onDispose(() {
      _sub?.cancel();
      _poll?.cancel();
    });
    _sub = _connectivity.onConnectivityChanged.listen(_onInterfaces);
    unawaited(_refresh());
    return const AppNetworkStatus();
  }

  Future<void> recheck() => _refresh();

  void _onInterfaces(List<ConnectivityResult> results) {
    unawaited(_refresh(interfaces: results));
  }

  Future<void> _refresh({List<ConnectivityResult>? interfaces}) async {
    final gen = ++_probeGen;
    final links = interfaces ?? await _connectivity.checkConnectivity();
    if (gen != _probeGen) return;

    if (!_hasInterface(links)) {
      _misses = 0;
      _setKind(AppNetworkKind.offline);
      _schedulePoll();
      return;
    }

    final reachable = await _probeReachable();
    if (gen != _probeGen) return;
    if (reachable) {
      _misses = 0;
      _setKind(AppNetworkKind.online);
    } else {
      _misses += 1;
      // Un ping fallido no basta: en casa también hay un corte breve.
      if (_misses >= 2 || state.showBanner) {
        _setKind(AppNetworkKind.degraded);
      }
    }
    _schedulePoll();
  }

  void _setKind(AppNetworkKind kind) {
    if (state.kind == kind) return;
    final previous = state;
    if (kind == AppNetworkKind.online) {
      state = AppNetworkStatus(kind: kind, lastOnlineAt: DateTime.now());
      return;
    }
    state = AppNetworkStatus(
      kind: kind,
      lastOnlineAt: previous.lastOnlineAt,
    );
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (state.isOnline) return;
    _poll = Timer(const Duration(seconds: 12), () => unawaited(_refresh()));
  }
}

bool _hasInterface(List<ConnectivityResult> results) {
  return results.any((item) => item != ConnectivityResult.none);
}

Future<bool> _probeReachable() async {
  final base = SupabaseConfig.url.trim();
  if (base.isEmpty) return true;
  try {
    final uri = Uri.parse('$base/auth/v1/health');
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 4));
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}
