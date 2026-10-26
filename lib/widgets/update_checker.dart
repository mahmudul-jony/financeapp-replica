/// অ্যাপ শুরুতে আপডেট চেক করে নোটিফিকেশন উইজেট দেখানোর জন্য স্টেটফুল উইজেট।
///
/// `initState`-এ `UpdateProvider.checkForUpdates()` কল করে এবং
/// `UpdateNotificationWidget` রেন্ডার করে। এটি যেকোনো স্ক্রিনের চিলড্রেনে যোগ করা যায়
/// বিদ্যমান UI অপ্রয়োজনে পরিবর্তন না করে।
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:financeapp/providers/update_provider.dart';
import 'package:financeapp/widgets/update_notification_widget.dart';

class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    // flutter ফ্রেমের প্রথম রেন্ডারের পর আপডেট চেক শুরু করা হয়,
    // যাতে বিল্ড প্রসessin মাঝে অ্যাসিনক কলের সমস্যা না হয়।
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UpdateProvider>().checkForUpdates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const UpdateNotificationWidget();
  }
}
