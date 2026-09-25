import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'pc_sync_repository.dart';

/// The [PcSyncRepository] bound to the app DB and clock.
final pcSyncRepositoryProvider = Provider<PcSyncRepository>(
  (ref) => PcSyncRepository(ref.watch(databaseProvider), () => ref.read(clockProvider)()),
);

/// The saved GitHub token, or null if none is set.
final syncTokenProvider = FutureProvider<String?>(
  (ref) => ref.watch(pcSyncRepositoryProvider).readToken(),
);

/// The gist id from the last successful sync, or null before the first one.
final syncGistIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(pcSyncRepositoryProvider).readGistId(),
);
