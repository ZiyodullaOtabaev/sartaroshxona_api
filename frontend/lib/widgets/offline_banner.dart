import 'package:flutter/material.dart';
import 'package:sartaroshxona/services/offline_cache_service.dart';

/// Internet yo'q bo'lganda ekran tepasida ko'rsatiladigan banner
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineCacheService().connectivityStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (isOnline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.orange.shade800,
          child: const SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Internet aloqasi yo\'q',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
