import 'package:flutter/material.dart';
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/widgets/account_card.dart';
import 'package:financeapp/widgets/summary_card.dart';

class VerticalStackedCards extends StatefulWidget {
  final List<DashboardCardItem> items;
  const VerticalStackedCards({required this.items, super.key});

  @override
  State<VerticalStackedCards> createState() => _VerticalStackedCardsState();
}

class _VerticalStackedCardsState extends State<VerticalStackedCards> {
  late List<DashboardCardItem> _displayItems;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _displayItems = List.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant VerticalStackedCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      setState(() {
        _displayItems = List.from(widget.items);
      });
    }
  }

  void _nextCard() {
    if (_isAnimating || _displayItems.isEmpty) return;
    setState(() => _isAnimating = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        if (_displayItems.isNotEmpty) {
          final topItem = _displayItems.removeAt(0);
          _displayItems.add(topItem);
        }
        _isAnimating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != 0) {
          _nextCard();
        }
      },
      child: SizedBox(
        height: 245,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.topCenter,
          children: _displayItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildCard(index, item);
          }).toList().reversed.toList(),
        ),
      ),
    );
  }

  Widget _buildCard(int index, DashboardCardItem item) {
    double topOffset = index * 18.0;
    double scale = 1.0 - (index * 0.05);
    double opacity = index == 0 ? 1.0 : (0.7 - (index * 0.2)).clamp(0.0, 1.0);

    if (index == 0 && _isAnimating) {
      opacity = 0.0;
      topOffset -= 40;
      scale = 0.9;
    }

    Widget cardWidget;
    String itemKey;

    if (item.type == DashboardCardType.summary) {
      itemKey = 'summary_card';
      cardWidget = SummaryCard(
        totalWithdrawable: item.summaryData!['totalWithdrawable'],
        totalExpense: item.summaryData!['totalExpense'],
        expenseChangePercentage: item.summaryData!['expenseChangePercentage'],
      );
    } else {
      final card = item.walletData!;
      itemKey = 'wallet_${card.bankName}_${card.balance}';
      cardWidget = AccountCard(data: card);
    }

    return AnimatedPositioned(
      key: ValueKey(itemKey),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: topOffset,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: scale,
          child: cardWidget,
        ),
      ),
    );
  }
}
