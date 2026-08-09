import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

// Provider for notifications
final notificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return const Stream.empty();
  return FirestoreService().getUserNotifications(user.uid);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero AppBar ──
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.espresso,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D0B08), Color(0xFF1C1208), Color(0xFF2E1E0A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(72, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('NOTIFICATIONS',
                          style: AppTextStyles.eyebrow.copyWith(color: AppColors.gold3, letterSpacing: 2.5)),
                        const SizedBox(height: 6),
                        Text('Your Alerts',
                          style: AppTextStyles.display2.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Notification List ──
          notifsAsync.when(
            data: (notifs) {
              if (notifs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.goldBg,
                            border: Border.all(color: AppColors.goldBorder),
                            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 16)],
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: AppColors.gold, size: 38),
                        ),
                        const SizedBox(height: 20),
                        Text('All caught up!', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 8),
                        Text('No new notifications right now.',
                          style: AppTextStyles.body2, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _NotifCard(
                      notif: notifs[i],
                      onRead: () => FirestoreService()
                          .markNotificationRead(notifs[i]['id'] as String),
                    ),
                    childCount: notifs.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e', style: AppTextStyles.body2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onRead;
  const _NotifCard({required this.notif, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final isRead = notif['isRead'] as bool? ?? false;
    final title = notif['title'] as String? ?? 'Notification';
    final body = notif['body'] as String? ?? '';
    final ts = notif['createdAt'];
    String timeStr = '';
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
        timeStr = DateFormat('d MMM, hh:mm a').format(dt);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: isRead ? null : onRead,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isRead ? AppColors.bg2 : AppColors.cardWhite,
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.goldBorder.withValues(alpha: 0.6),
          ),
          boxShadow: isRead
              ? []
              : [BoxShadow(color: AppColors.gold.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left accent
            Container(
              width: 4,
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                gradient: isRead ? null : AppColors.goldGradient,
                color: isRead ? AppColors.border : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRead ? AppColors.bg3 : AppColors.goldBg,
                      border: Border.all(
                        color: isRead ? AppColors.border : AppColors.goldBorder,
                      ),
                    ),
                    child: Icon(
                      isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                      color: isRead ? AppColors.text4 : AppColors.gold,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: AppTextStyles.body1.copyWith(
                                  fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold,
                                ),
                              ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(body, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(timeStr, style: AppTextStyles.caption.copyWith(color: AppColors.text4, fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
