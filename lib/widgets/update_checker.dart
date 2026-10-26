import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:financeapp/providers/update_provider.dart';
import 'package:financeapp/widgets/update_notification_widget.dart';

class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UpdateProvider>().checkForUpdates();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Check for updates when app returns to the foreground
      context.read<UpdateProvider>().checkForUpdates(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const UpdateNotificationWidget();
  }
}
