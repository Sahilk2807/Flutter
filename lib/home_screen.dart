// Location: schedule_pro/lib/home_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:schedule_pro/services/notification_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WebViewController _controller;
  bool _isOffline = false;
  
  // IMPORTANT: Replace this with your live website URL from InfinityFree
  final String _url = "https://your-domain.infinityfreeapp.com/index.php";

  BannerAd? _bannerAd;
  AppOpenAd? _appOpenAd;
  RewardedAd? _rewardedAd;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadAppOpenAd();
    _loadBannerAd();
    _loadRewardedAd();

    final WebViewController controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _controller.runJavaScript(
              "window.addEventListener('offline', (event) => { ScheduleProChannel.postMessage('offline'); });"
              "window.addEventListener('online', (event) => { ScheduleProChannel.postMessage('online'); });"
              "if (!navigator.onLine) { ScheduleProChannel.postMessage('offline'); }"
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'ScheduleProChannel',
        onMessageReceived: (JavaScriptMessage message) {
          handleJsMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(_url));

    _controller = controller;
  }

  void handleJsMessage(String message) {
    if (message == 'offline') {
      if (!_isOffline) setState(() { _isOffline = true; });
    } else if (message == 'online') {
      if (_isOffline) setState(() { _isOffline = false; });
    } else if (message == 'showRewardedAd') {
      _rewardedAd?.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print("Reward earned: ${reward.amount} ${reward.type}");
      });
      _loadRewardedAd();
    } else {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'scheduleNotification') {
          final task = data['task'];
          _notificationService.scheduleNotification(
            id: int.parse(task['id'].toString()),
            title: 'Reminder: ${task['title']}',
            body: 'Your task is scheduled for now. Time to get it done!',
            scheduledTime: DateTime.parse(task['scheduledTime']),
          );
        }
      } catch (e) {
        print("Could not parse JS message as JSON: $e");
      }
    }
  }

  void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: 'ca-app-pub-8166003433787441/3957829753',
      request: AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAd!.show();
        },
        onAdFailedToLoad: (error) {
          print('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-8166003433787441/7602912360',
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {}),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-8166003433787441/5114713343',
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => print('RewardedAd failed to load: $error'),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _appOpenAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.red,
                padding: EdgeInsets.all(12),
                child: Text(
                  '🚫 No Internet Connection. Please turn on Mobile Data to use Schedule Pro.',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
            if (_bannerAd != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}