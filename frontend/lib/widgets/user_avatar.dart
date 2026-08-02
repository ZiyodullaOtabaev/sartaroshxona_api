import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sartaroshxona/utils/app_constants.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isVip;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.isVip = false,
    this.onTap,
  });

  String get _fullUrl {
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) return '';
    final url = avatarUrl!.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${AppConstants.baseUrl}$url';
    return '${AppConstants.baseUrl}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    final hasImage = _fullUrl.isNotEmpty;

    Widget avatarCore = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isVip
            ? const LinearGradient(
                colors: [Color(0xFFF1C40F), Color(0xFFE67E22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [const Color(0xFF10B981), const Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: (isVip ? Colors.amber : const Color(0xFF10B981)).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isVip ? 2.5 : 0),
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: _fullUrl,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  placeholder: (context, url) => Container(
                    color: Colors.black26,
                    child: Center(
                      child: SizedBox(
                        width: radius * 0.8,
                        height: radius * 0.8,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildFallback(initial),
                )
              : _buildFallback(initial),
        ),
      ),
    );

    if (isVip) {
      avatarCore = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCore,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1117),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.amber,
                size: 14,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarCore,
      );
    }

    return avatarCore;
  }

  Widget _buildFallback(String initial) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
