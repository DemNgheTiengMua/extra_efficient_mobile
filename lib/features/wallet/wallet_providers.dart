import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/provider_retry.dart';
import '../auth/auth_provider.dart';
import 'wallet_models.dart';
import 'wallet_repository.dart';

export '../../core/platform/external_url_launcher.dart'
    show UrlLauncherAdapter, urlLauncherAdapterProvider;

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(dioProvider));
});

class WalletSummaryNotifier extends AsyncNotifier<WalletSummary?> {
  @override
  Future<WalletSummary?> build() async {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated) {
      return null;
    }
    return ref.read(walletRepositoryProvider).getWallet();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(walletRepositoryProvider).getWallet(),
    );
  }
}

final walletSummaryProvider =
    AsyncNotifierProvider<WalletSummaryNotifier, WalletSummary?>(
  WalletSummaryNotifier.new,
  retry: noProviderRetry,
);

final creditPackagesProvider = FutureProvider<List<CreditPackage>>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  if (!authState.isAuthenticated) {
    return const [];
  }
  return ref.read(walletRepositoryProvider).getPackages();
}, retry: noProviderRetry);
