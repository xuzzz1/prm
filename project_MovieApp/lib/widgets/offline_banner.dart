import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../screens/user/downloads_screen.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;
  final bool navigateToDownloadsOnTap;
  final bool showBanner;

  const OfflineBanner({
    super.key,
    required this.child,
    this.navigateToDownloadsOnTap = true,
    this.showBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        return Column(
          children: [
            if (showBanner && connectivity.isOffline)
              _OfflineBannerTile(
                onTap: navigateToDownloadsOnTap
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        )
                    : null,
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _OfflineBannerTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _OfflineBannerTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFD32F2F),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bạn đang offline. Nhấn vào đây để đến danh sách phim đã tải',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
