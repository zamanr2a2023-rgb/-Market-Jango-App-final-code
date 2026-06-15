import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';

import 'package:market_jango/core/localization/Keys/vendor_kay.dart';

import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/screen/buyer_massage/data/chat_block_data.dart';
import 'package:market_jango/core/screen/buyer_massage/data/chat_read_data.dart';
import 'package:market_jango/core/screen/buyer_massage/data/meassage_data.dart'; // chatListProvider
import 'package:market_jango/core/screen/buyer_massage/model/chat_history_route_model.dart';
import 'package:market_jango/core/screen/buyer_massage/model/massage_list_model.dart';
import 'package:market_jango/core/screen/buyer_massage/widget/custom_textfromfield.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/image_controller.dart';

import '../../../localization/Keys/buyer_kay.dart';
import 'global_chat_screen.dart';

Future<void> _openChatBlockActionForThread(
  BuildContext context,
  WidgetRef ref,
  ChatThread chat,
) async {
  var snap = ref.read(blockedChatUserIdsProvider);
  if (!snap.hasValue) {
    try {
      await ref.read(blockedChatUserIdsProvider.future);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }
  }
  snap = ref.read(blockedChatUserIdsProvider);
  final ids = snap.value ?? {};
  if (!context.mounted) return;
  final isBlocked = ids.contains(chat.partnerId);

  if (isBlocked) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock user'),
        content: Text('Allow ${chat.partnerName} to message you again?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unblock')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ChatBlockApi.unblockUser(chat.partnerId);
      await refreshChatBlockAndInbox(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Block user'),
      content: Text(
        'Block ${chat.partnerName}? You will not receive messages from them.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ChatBlockApi.blockUser(chat.partnerId);
    await refreshChatBlockAndInbox(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class GlobalMassageScreen extends ConsumerStatefulWidget {
  const GlobalMassageScreen({super.key});
  static final routeName = "/buyerMassageScreen";

  @override
  ConsumerState<GlobalMassageScreen> createState() => _GlobalMassageScreenState();
}

class _GlobalMassageScreenState extends ConsumerState<GlobalMassageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshChatInbox(ref);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatThread> _filterChatList(List<ChatThread> list) {
    if (_searchQuery.isEmpty) {
      return list;
    }
    return list.where((chat) {
      final partnerName = chat.partnerName.toLowerCase();
      final lastMessage = chat.lastMessage.toLowerCase();
      return partnerName.contains(_searchQuery) || 
             lastMessage.contains(_searchQuery);
    }).toList();
  }

  Future<void> _refreshMessages() async {
    await refreshChatInbox(ref);
    try {
      await ref.read(blockedChatUserIdsProvider.future);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(chatListProvider.notifier).markAllRead();
      ref.invalidate(chatUnreadCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final chatState = ref.watch(chatListProvider);
    final unreadAsync = ref.watch(chatUnreadCountProvider);
    // Preload blocked-user ids (same API for every role) so long-press actions work immediately.
    ref.watch(blockedChatUserIdsProvider);

    final totalUnread = unreadAsync.valueOrNull?.totalUnread ?? 0;
    final hasAnyUnread = chatState.valueOrNull?.any((c) => c.isUnread) == true ||
        totalUnread > 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ref.t(BKeys.messages), style: theme.titleLarge),
                  ),
                  if (totalUnread > 0)
                    Container(
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AllColor.blue500,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        totalUnread > 99 ? '99+' : '$totalUnread',
                        style: TextStyle(
                          color: AllColor.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (hasAnyUnread)
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AllColor.loginButtomColor,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16.h),
              CustomTextFromField(
                hintText: ref.t(BKeys.search),
                prefixIcon: Icons.search_rounded,
                controller: _searchController,
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshMessages,
                  child: chatState.when(
                    data: (list) {
                      final filteredList = _filterChatList(list);
                      return ChatListView(chatData: filteredList);
                    },
                    loading: () => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 120.h),
                        Center(child: Text(ref.t(VKeys.loding))),
                      ],
                    ),
                    error: (e, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 120.h),
                        Center(child: Text('Error: $e')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat list
class ChatListView extends ConsumerWidget {
  const ChatListView({super.key, required this.chatData});
  final List<ChatThread> chatData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chatData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 80.h),
          Center(
            child: Text(
              'No messages yet',
              style: TextStyle(color: AllColor.grey500, fontSize: 14.sp),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: chatData.length,
      separatorBuilder: (_, __) =>
          Divider(height: 22.h, color: AllColor.grey500),
      itemBuilder: (_, i) {
        final chat = chatData[i];
        final isUnread = chat.isUnread;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUnread)
                Container(
                  width: 10.w,
                  height: 10.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AllColor.blue500,
                  ),
                ),
              if (isUnread && chat.unreadCount > 0) ...[
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AllColor.blue500,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    chat.unreadCount > 9 ? '9+' : '${chat.unreadCount}',
                    style: TextStyle(
                      color: AllColor.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(width: 6.w),
              ClipOval(
                child: FirstTimeShimmerImage(
                  imageUrl: chat.partnerImage,
                  width: 44.r,
                  height: 44.r,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chat.partnerName,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              FittedBox(
                child: Row(
                  children: [
                    Text(
                      chat.lastMessageTime,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AllColor.black54,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Icon(Icons.arrow_forward_ios_outlined, size: 15.sp),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Text(
            chat.lastMessage,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: TextStyle(
              color: isUnread ? AllColor.black87 : AllColor.grey,
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onLongPress: () => _openChatBlockActionForThread(context, ref, chat),
          onTap: () async {
            try {
              // Use centralized AuthLocalStorage to get user ID
              final authStorage = AuthLocalStorage();
              final myUserId = await authStorage.getUserId();
              
              if (myUserId == null || myUserId.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User ID not found. Please login again.'),
                    ),
                  );
                }
                return;
              }

              final myUserIdInt = int.tryParse(myUserId);
              if (myUserIdInt == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid user ID. Please login again.'),
                    ),
                  );
                }
                return;
              }

              if (chat.partnerId <= 0) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cannot open chat: partner not found. Pull to refresh and try again.',
                      ),
                    ),
                  );
                }
                ref.invalidate(chatListProvider);
                return;
              }

              if (context.mounted) {
                await ref
                    .read(chatListProvider.notifier)
                    .markConversationRead(chat.partnerId);
                ref.invalidate(chatUnreadCountProvider);

                await context.push(
                  GlobalChatScreen.routeName,
                  extra: ChatArgs(
                    partnerId: chat.partnerId,
                    partnerName: chat.partnerName,
                    partnerImage: chat.partnerImage,
                    myUserId: myUserIdInt,
                  ),
                );
                if (context.mounted) {
                  await refreshChatInbox(ref);
                }
              }
            } catch (e) {
              Logger().e('Error navigating to chat: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to open chat: ${e.toString()}'),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
