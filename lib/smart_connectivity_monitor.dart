// lib/smart_connectivity_monitor.dart
//
// Public API — import only this file in your app:
//   import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';

library smart_connectivity_monitor;

export 'core/cache/connectivity_cache.dart';
export 'core/models/connectivity_config.dart';
export 'core/models/connectivity_result_model.dart';
export 'core/services/retry_queue.dart';
export 'core/utils/connectivity_exceptions.dart';
export 'features/connectivity/controller/connectivity_controller.dart';
export 'features/connectivity/state/connectivity_state.dart';
export 'src/smart_connectivity_monitor_base.dart';
export 'widgets/connectivity_banner.dart';
export 'widgets/connectivity_builder.dart';
export 'widgets/connectivity_mixin.dart';
export 'widgets/connectivity_snackbar.dart';
