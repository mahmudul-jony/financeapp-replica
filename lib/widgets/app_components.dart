import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/providers/finance_provider.dart';

// =============================================================================
// REUSABLE UI COMPONENTS (Component Library)
// =============================================================================

// -----------------------------------------------------------------------------
// SECTION 7: FILTERING
// -----------------------------------------------------------------------------

class AppFilterBar extends StatelessWidget {
  final FilterType currentFilter;
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Function(FilterType) onFilterChanged;

  const AppFilterBar({
    required this.currentFilter,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onFilterChanged,
    super.key,
  });

  String _getLabel() {
    switch (currentFilter) {
      case FilterType.today:
        return DateFormat('dd MMM, yyyy').format(selectedDate);
      case FilterType.week:
        final start = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return "${DateFormat('dd').format(start)} - ${DateFormat('dd MMM').format(end)}, ${start.year}";
        }
        return "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}, ${start.year}";
      case FilterType.month:
        return DateFormat('MMMM, yyyy').format(selectedDate);
      case FilterType.year:
        return DateFormat('yyyy').format(selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderGrey, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrevious, 
            icon: const Icon(Icons.chevron_left, color: AppColors.secondaryText, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          PopupMenuButton<FilterType>(
            onSelected: onFilterChanged,
            offset: const Offset(0, 40),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getLabel(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primaryText),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.secondaryText),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: FilterType.today, child: Text('Today')),
              const PopupMenuItem(value: FilterType.week, child: Text('Week')),
              const PopupMenuItem(value: FilterType.month, child: Text('Month')),
              const PopupMenuItem(value: FilterType.year, child: Text('Year')),
            ],
          ),
          IconButton(
            onPressed: onNext, 
            icon: const Icon(Icons.chevron_right, color: AppColors.secondaryText, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION 1: BUTTONS
// -----------------------------------------------------------------------------

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isFullWidth;
  final Color? color;

  const AppButton({
    required this.label, required this.onTap, this.isFullWidth = true, this.color, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const AppOutlinedButton({
    required this.label, required this.onTap, this.icon = Icons.add_rounded, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryPurple,
          side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION 2: ICONS
// -----------------------------------------------------------------------------

class AppEditIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;
  const AppEditIconButton({required this.onTap, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.edit_square, color: color ?? AppColors.primaryPurple, size: 22),
      onPressed: onTap,
    );
  }
}

class AppDeleteIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const AppDeleteIconButton({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.expenseAlertText, size: 24),
      onPressed: onTap,
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION 3: INPUT & SELECTION FIELDS
// -----------------------------------------------------------------------------

class AppTextField extends StatelessWidget {
  final String? label;
  final String hint;
  final TextEditingController controller;
  final bool readOnly;
  final TextInputType? keyboardType;

  const AppTextField({
    this.label, required this.hint, required this.controller, this.readOnly = false, this.keyboardType, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(label!, style: AppTypography.caption),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: (keyboardType?.toString().contains('number') == true ||
                           keyboardType?.toString().contains('decimal') == true)
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: readOnly ? AppColors.borderGrey : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderGrey)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderGrey)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1)),
          ),
        ),
      ],
    );
  }
}

class AppSelectionField extends StatelessWidget {
  final String? label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const AppSelectionField({
    this.label, required this.value, required this.icon, required this.onTap, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(label!, style: AppTypography.caption),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.secondaryText, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(value, style: AppTypography.body.copyWith(fontSize: 14))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AppAmountInput extends StatelessWidget {
  final TextEditingController controller;
  final String subLabel;

  const AppAmountInput({required this.controller, required this.subLabel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('৳', style: TextStyle(color: AppColors.primaryText, fontSize: 28, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            IntrinsicWidth(
              child: TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: AppTypography.largeAmount.copyWith(fontSize: 44),
                decoration: const InputDecoration(border: InputBorder.none, hintText: '0', isDense: true, contentPadding: EdgeInsets.zero),
              ),
            ),
          ],
        ),
        Text(subLabel, style: AppTypography.subTitle),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION 4: WALLET CARDS
// -----------------------------------------------------------------------------

class WalletCardItem extends StatelessWidget {
  final String name;
  final String balance;
  final String? frozen;
  final bool isSelected;
  final VoidCallback? onTap;
  final double? width;

  const WalletCardItem({
    required this.name,
    required this.balance,
    this.frozen,
    required this.isSelected,
    this.onTap,
    this.width,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderGrey,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFF7252FD) : const Color(0xFFF2F2F2),
                  border: isSelected
                      ? null
                      : Border.all(color: const Color(0xFFDCDCE0), width: 1.2),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F1F1F),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                  if (frozen != null)
                    Text(
                      frozen!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A7A7A),
                        fontSize: 12,
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

class AppWalletSelector extends StatelessWidget {
  final String selectedAccount;
  final Function(String) onSelect;
  final List<Map<String, dynamic>> accounts;

  const AppWalletSelector({
    required this.selectedAccount,
    required this.onSelect,
    required this.accounts,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final acc = accounts[index];
          final bool isSelected = selectedAccount == acc['name'];
          return WalletCardItem(
            name: acc['name'] ?? '',
            balance: acc['balance'] ?? '',
            frozen: acc['frozen'],
            isSelected: isSelected,
            width: 160,
            onTap: () => onSelect(acc['name']),
          );
        },
      ),
    );
  }
}

class AppStaticWalletCard extends StatelessWidget {
  final Map<String, dynamic> acc;
  final String label;
  final VoidCallback onTap;

  const AppStaticWalletCard({
    required this.acc,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = acc['name'] != 'Select' && acc['name'] != 'Select Wallet';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: 6),
        WalletCardItem(
          name: acc['name'] ?? '',
          balance: acc['balance'] ?? '',
          frozen: acc['frozen'],
          isSelected: isSelected,
          onTap: onTap,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION 5: DISPLAY CARDS
// -----------------------------------------------------------------------------

class AppDetailsSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String title;
  final Color? valueColor;
  final IconData? icon;

  const AppDetailsSummaryCard({
    required this.label, required this.value, required this.title, this.valueColor, this.icon, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.borderRadiusLarge,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 15))
        ]
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
          ],
          Text(title, style: AppTypography.titleWhite.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: AppTypography.captionMuted),
          const SizedBox(height: 20),
          Container(height: 1, width: 40, color: Colors.white10),
          const SizedBox(height: 20),
          Text(value, style: AppTypography.largeAmount.copyWith(color: valueColor ?? Colors.white, fontSize: 38, letterSpacing: -0.5)),
          const Text('Current Balance', style: AppTypography.captionMuted),
        ],
      ),
    );
  }
}

class AppSummaryInfoCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData? icon;
  final Color? amountColor;
  final String? subtitle;

  const AppSummaryInfoCard({
    required this.title,
    required this.amount,
    this.icon,
    this.amountColor,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.backgroundGrey,
              child: Icon(icon, color: AppColors.primaryPurple, size: 24),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (subtitle != null)
                  Text(subtitle!, style: AppTypography.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: amountColor ?? AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION 6: ERROR & FEEDBACK
// -----------------------------------------------------------------------------

class AppErrorBanner extends StatefulWidget {
  final String? message;
  final VoidCallback? onDismissed;
  const AppErrorBanner({this.message, this.onDismissed, super.key});

  @override
  State<AppErrorBanner> createState() => _AppErrorBannerState();
}

class _AppErrorBannerState extends State<AppErrorBanner> {
  String? _visibleMessage;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _visibleMessage = widget.message;
    if (_visibleMessage != null) _startTimer();
  }

  @override
  void didUpdateWidget(AppErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      setState(() => _visibleMessage = widget.message);
      _hideTimer?.cancel();
      if (widget.message != null) _startTimer();
    }
  }

  void _startTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      _hideBanner();
    });
  }

  void _hideBanner() {
    if (mounted) {
      setState(() => _visibleMessage = null);
      widget.onDismissed?.call();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_visibleMessage == null || _visibleMessage!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(bottom: BorderSide(color: Colors.red.shade100)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _visibleMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            onPressed: _hideBanner,
            icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
