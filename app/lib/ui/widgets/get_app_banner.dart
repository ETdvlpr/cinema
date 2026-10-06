import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'status_banner.dart';

/// Always the newest APK attached to a GitHub release (see app/README.md, "Releasing").
const _apkUrl = 'https://github.com/ETdvlpr/cinema/releases/latest/download/addis-cinema.apk';
const _dismissedKey = 'get_app_banner_dismissed';

/// On the website in an Android browser, offers the installable app. Hidden once dismissed.
class GetAppBanner extends StatefulWidget {
  const GetAppBanner({super.key});

  @override
  State<GetAppBanner> createState() => _GetAppBannerState();
}

class _GetAppBannerState extends State<GetAppBanner> {
  static final _applies = kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (_applies) {
      SharedPreferences.getInstance().then((prefs) {
        if (mounted && !(prefs.getBool(_dismissedKey) ?? false)) setState(() => _visible = true);
      });
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    (await SharedPreferences.getInstance()).setBool(_dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: StatusBanner(
        icon: Icons.android_rounded,
        message: 'Get the Android app. It opens instantly and runs smoother.',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(_apkUrl), mode: LaunchMode.externalApplication),
              child: const Text('Install'),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
