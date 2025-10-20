import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/AppNotificationManager.dart';

class NotificationIcon extends StatelessWidget {
  final VoidCallback onTap;

  const NotificationIcon({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AppNotificationManager notificationManager = AppNotificationManager();

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.notifications),
          ),
          ValueListenableBuilder<int>(
            valueListenable: notificationManager.notificationCounter,
            builder: (context, count, child) {
              return count > 0
                  ? Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
