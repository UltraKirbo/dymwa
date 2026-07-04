import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  final String _androidRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  final String _iosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  Future<void> init() async {
    if (kIsWeb) return; // AdMob ne fonctionne pas sur le web par défaut
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  void loadRewardedAd() {
    if (_isRewardedAdLoading || kIsWeb) return;
    _isRewardedAdLoading = true;

    String adUnitId = Platform.isAndroid ? _androidRewardedAdUnitId : _iosRewardedAdUnitId;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          print('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  void showRewardedAd(Function onRewardEarned) {
    if (_rewardedAd == null) {
      print('Warning: attempt to show rewarded before loaded.');
      // Re-load for next time
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load next ad
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
        onRewardEarned();
      }
    );
  }
}
