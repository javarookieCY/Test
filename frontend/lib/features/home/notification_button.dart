import 'package:flutter/material.dart';

import '../../notification/notification_service.dart';
import 'square_icon_button.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  Future<void> _send(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    bool sent;
    try {
      sent = await NotificationService.instance.showNow(title, body);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('通知傳送失敗：$error')),
      );
      return;
    }

    if (!sent) {
      messenger.showSnackBar(
        const SnackBar(content: Text('沒有通知權限，請到手機的「設定 → 通知」開啟')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SquareIconButton(
      icon: Icons.notifications_none,
      onPressed: () {
        _send(context);
      },
    );
  }
}
