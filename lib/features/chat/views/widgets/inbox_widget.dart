import 'package:edumap_portfolio_project/features/app/views/widgets/others/mfa_widget.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/conversation_model.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:edumap_portfolio_project/features/chat/views/screens/chat_group_screen.dart';
import 'package:edumap_portfolio_project/features/chat/views/screens/chat_screen.dart';
import 'package:edumap_portfolio_project/features/chat/views/screens/user_search_screen.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/tabs/chat_tab.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/tabs/friends_tab.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/tabs/request_tab.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';

class InboxWidget extends StatefulWidget {
  const InboxWidget({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
  });

  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;

  @override
  State<InboxWidget> createState() => _InboxWidgetState();
}

class _InboxWidgetState extends State<InboxWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.chatRepository.setOnline(widget.currentUserId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.chatRepository.setOffline(widget.currentUserId);
    super.dispose();
  }

  void _openSearch() => AppNavigator(
    screen: UserSearchScreen(
      currentUserId: widget.currentUserId,
      currentUsername: widget.currentUsername,
      currentProfilePhoto: widget.currentProfilePhoto,
      chatRepository: widget.chatRepository,
    ),
  ).navigate(context);

  void _openCreateGroup() => AppNavigator(
    screen: CreateGroupScreen(
      currentUserId: widget.currentUserId,
      currentUsername: widget.currentUsername,
      currentProfilePhoto: widget.currentProfilePhoto,
      chatRepository: widget.chatRepository,
    ),
  ).navigate(context);

  void _openChat(ConversationModel conversation) => AppNavigator(
    screen: ChatScreen(
      conversation: conversation,
      currentUserId: widget.currentUserId,
      currentUsername: widget.currentUsername,
      currentProfilePhoto: widget.currentProfilePhoto,
      chatRepository: widget.chatRepository,
    ),
  ).navigate(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return NetworkWidget(
      child: MfaWidget(
        authRepository: AuthRepository(),
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Inbox',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Unread badge next to title
                      StreamBuilder<int>(
                        stream: widget.chatRepository.watchTotalUnreadCount(
                          widget.currentUserId,
                        ),
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return AnimatedScale(
                            scale: 1,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      // Compact icon actions in header
                      _HeaderIconButton(
                        icon: Icons.group_add_rounded,
                        tooltip: 'New Group',
                        onTap: _openCreateGroup,
                      ),
                      const SizedBox(width: 4),
                      _HeaderIconButton(
                        icon: Icons.search_rounded,
                        tooltip: 'Search',
                        onTap: _openSearch,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(3),
                      labelColor: colorScheme.onPrimary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: theme.textTheme.labelMedium,
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      tabs: const [
                        Tab(text: 'Chats'),

                        Tab(text: 'Friends'),
                        Tab(text: 'Requests'),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ChatsTab(
                        currentUserId: widget.currentUserId,
                        chatRepository: widget.chatRepository,
                        onOpenChat: _openChat,
                      ),

                      FriendsTab(
                        currentUserId: widget.currentUserId,
                        currentUsername: widget.currentUsername,
                        currentProfilePhoto: widget.currentProfilePhoto,
                        chatRepository: widget.chatRepository,
                        onOpenChat: _openChat,
                      ),
                      RequestsTab(
                        currentUserId: widget.currentUserId,
                        chatRepository: widget.chatRepository,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
