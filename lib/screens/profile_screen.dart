import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/signin_screen.dart';
import 'package:financeapp/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Profile', style: AppTypography.title), centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            _buildProfileHeader(),
            const SizedBox(height: 40),
            _buildSettingsList(),
            const SizedBox(height: 40),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final authUser = context.watch<AuthService>().currentUser;
    final String displayName = (authUser?.displayName != null && authUser!.displayName!.isNotEmpty)
        ? authUser.displayName!
        : 'Mahmudul Hasan';
    final String email = (authUser?.email != null && authUser!.email.isNotEmpty)
        ? authUser.email
        : 'mahmudul@example.com';
    final String? photoUrl = authUser?.photoUrl;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.softLightPurple,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.person_rounded, size: 60, color: AppColors.primaryPurple)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.primaryPurple, shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(email, style: AppTypography.caption),
      ],
    );
  }

  Widget _buildSettingsList() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferences', style: AppTypography.caption),
        AppSpacing.verticalGap,
        _buildWeekStartDaySelector(),
        AppSpacing.verticalGap,
        _buildToggleItem('Dark Mode', Icons.dark_mode_rounded, _isDarkMode, (v) => setState(() => _isDarkMode = v)),
        AppSpacing.verticalGap,
        _buildClickableItem('Account Settings', Icons.manage_accounts_rounded),
        AppSpacing.verticalGap,
        _buildClickableItem('Notifications', Icons.notifications_active_rounded),
        AppSpacing.verticalGap,
        _buildSyncButton(),
        AppSpacing.verticalGap,
        _buildResetButton(),
      ],
    ),
  );

  Widget _buildWeekStartDaySelector() {
    final provider = context.watch<FinanceProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium),
      child: Row(
        children: [
          const Icon(Icons.calendar_view_week_rounded, color: AppColors.secondaryText, size: 22),
          const SizedBox(width: 16),
          const Expanded(child: Text('Week Start Day', style: TextStyle(fontWeight: FontWeight.w500))),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: provider.weekStartDay,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryPurple),
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryPurple, fontSize: 14),
              onChanged: (int? newDay) {
                if (newDay != null) {
                  context.read<FinanceProvider>().setWeekStartDay(newDay);
                }
              },
              items: FinanceProvider.weekDaysMap.entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() => GestureDetector(
    onTap: () {
      final messenger = ScaffoldMessenger.of(context);
      final provider = context.read<FinanceProvider>();
      messenger.showSnackBar(const SnackBar(content: Text('Syncing with Google Sheets...')));
      provider.syncFromSheet();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium),
      child: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: AppColors.primaryPurple, size: 22),
          SizedBox(width: 16),
          Expanded(child: Text('Sync with Google Sheets', style: TextStyle(fontWeight: FontWeight.w500))),
          Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ],
      ),
    ),
  );

  Widget _buildResetButton() => GestureDetector(
    onTap: () => _showResetConfirmation(context),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium),
      child: const Row(
        children: [
          Icon(Icons.refresh_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 16),
          Expanded(child: Text('Reset App Data', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orange))),
          Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ],
      ),
    ),
  );

  Widget _buildToggleItem(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium),
    child: Row(
      children: [
        Icon(icon, color: AppColors.secondaryText, size: 22),
        const SizedBox(width: 16),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Switch.adaptive(value: value, activeTrackColor: AppColors.primaryPurple, onChanged: onChanged),
      ],
    ),
  );

  Widget _buildClickableItem(String label, IconData icon, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryText, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ],
      ),
    ),
  );

  Widget _buildLogoutButton() {
    final authService = context.watch<AuthService>();
    final isLoggingOut = authService.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextButton.icon(
        onPressed: isLoggingOut ? null : () => _showLogoutConfirmation(context),
        icon: isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.expenseAlertText),
              )
            : const Icon(Icons.logout_rounded, color: AppColors.expenseAlertText),
        label: Text(
          isLoggingOut ? 'Signing out...' : 'Logout Account',
          style: const TextStyle(color: AppColors.expenseAlertText, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: AppColors.expenseAlertBackground.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusSmall),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to sign out from your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<AuthService>().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset All Data?'),
        content: const Text('This will delete all your wallets, transactions, loans, and settings. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<FinanceProvider>().resetApp();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App data has been reset')));
            }, 
            child: const Text('Reset', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
