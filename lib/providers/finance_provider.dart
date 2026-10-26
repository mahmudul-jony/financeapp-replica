import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/wallet_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../models/investment_model.dart';
import '../models/savings_model.dart';
import '../services/sync_service.dart';

enum FilterType { today, week, month, year }

class FinanceProvider with ChangeNotifier {
  List<Wallet> _wallets = [];
  List<Category> _categories = [];
  List<TransactionModel> _transactions = [];
  List<LoanRecipient> _loanRecipients = [];
  List<LoanTransaction> _loanTransactions = [];
  List<Investment> _investments = [];
  List<InvestmentTransaction> _investmentTransactions = [];
  List<Savings> _savings = [];
  List<SavingsTransaction> _savingsTransactions = [];

  // Filter & Preferences State
  FilterType _currentFilter = FilterType.month;
  DateTime _selectedFilterDate = DateTime.now();
  int _weekStartDay = DateTime.monday;

  static const Map<int, String> weekDaysMap = {
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  FilterType get currentFilter => _currentFilter;
  DateTime get selectedFilterDate => _selectedFilterDate;
  int get weekStartDay => _weekStartDay;

  void setWeekStartDay(int day) {
    _weekStartDay = day;
    notifyListeners();
  }

  void setFilterType(FilterType type) {
    _currentFilter = type;
    notifyListeners();
  }

  void nextPeriod() {
    switch (_currentFilter) {
      case FilterType.today:
        _selectedFilterDate = _selectedFilterDate.add(const Duration(days: 1));
        break;
      case FilterType.week:
        _selectedFilterDate = _selectedFilterDate.add(const Duration(days: 7));
        break;
      case FilterType.month:
        _selectedFilterDate = DateTime(_selectedFilterDate.year, _selectedFilterDate.month + 1);
        break;
      case FilterType.year:
        _selectedFilterDate = DateTime(_selectedFilterDate.year + 1, _selectedFilterDate.month);
        break;
    }
    notifyListeners();
  }

  void previousPeriod() {
    switch (_currentFilter) {
      case FilterType.today:
        _selectedFilterDate = _selectedFilterDate.subtract(const Duration(days: 1));
        break;
      case FilterType.week:
        _selectedFilterDate = _selectedFilterDate.subtract(const Duration(days: 7));
        break;
      case FilterType.month:
        _selectedFilterDate = DateTime(_selectedFilterDate.year, _selectedFilterDate.month - 1);
        break;
      case FilterType.year:
        _selectedFilterDate = DateTime(_selectedFilterDate.year - 1, _selectedFilterDate.month);
        break;
    }
    notifyListeners();
  }

  void resetFilter() {
    _currentFilter = FilterType.month;
    _selectedFilterDate = DateTime.now();
    notifyListeners();
  }

  List<TransactionModel> get filteredTransactions {
    return _transactions.where((tx) {
      final date = tx.date;
      switch (_currentFilter) {
        case FilterType.today:
          return date.day == _selectedFilterDate.day && date.month == _selectedFilterDate.month && date.year == _selectedFilterDate.year;
        case FilterType.week:
          // Find start and end of week for selected date
          final startOfWeek = _selectedFilterDate.subtract(Duration(days: _selectedFilterDate.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && date.isBefore(endOfWeek);
        case FilterType.month:
          return date.month == _selectedFilterDate.month && date.year == _selectedFilterDate.year;
        case FilterType.year:
          return date.year == _selectedFilterDate.year;
      }
    }).toList();
  }

  List<Wallet> get wallets => _wallets;
  List<Wallet> get activeWallets => _wallets.where((w) => !w.isArchived).toList();
  List<Category> get categories => _categories;
  List<Category> get activeCategories => _categories.where((c) => !c.isArchived).toList();
  List<TransactionModel> get transactions => _transactions;
  List<LoanRecipient> get loanRecipients => _loanRecipients;
  List<LoanTransaction> get loanTransactions => _loanTransactions;
  List<Investment> get investments => _investments;
  List<InvestmentTransaction> get investmentTransactions => _investmentTransactions;
  List<Savings> get savingsList => _savings;
  List<SavingsTransaction> get savingsTransactions => _savingsTransactions;

  FinanceProvider() {
    fetchAll();
  }

  Future<void> fetchAll() async {
    await fetchWallets();
    await fetchCategories();
    await fetchTransactions();
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchSavings();
    await fetchSavingsTransactions();
  }

  void _validateAmount(double amount) {
    if (amount <= 0) throw Exception("Amount must be greater than zero");
    if (amount.isNaN || amount.isInfinite) throw Exception("Invalid amount");
  }

  Future<void> _ensureWalletActive(int walletId) async {
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (wallet.isArchived) throw Exception("Wallet is archived and cannot be used");
  }

  // --- Wallet Methods ---
  Future<void> fetchWallets() async {
    final data = await DatabaseHelper.instance.queryAll('wallets');
    _wallets = data.map((e) => Wallet.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addWallet(Wallet wallet) async {
    final walletToInsert = Wallet(
      name: wallet.name,
      balance: 0.0,
      color: wallet.color,
      isDefault: wallet.isDefault,
    );
    final id = await DatabaseHelper.instance.insert('wallets', walletToInsert.toMap());
    await fetchWallets();
    
    final savedWallet = _wallets.firstWhere((w) => w.id == id);
    _triggerWalletSync(savedWallet);

    if (wallet.balance > 0) {
      final defaultCat = _categories.firstWhere((c) => c.type == CategoryType.income, orElse: () => _categories.first);
      await addIncome(wallet.balance, savedWallet.id!, defaultCat.id!, DateTime.now(), "Initial Balance");
    }
  }

  void _triggerWalletSync(Wallet wallet) {
    try {
      SyncService.createTab(wallet.name);
    } catch (e) {
      print("Wallet sync error: $e");
    }
  }

  Future<void> updateWallet(Wallet wallet) async {
    final oldWallet = _wallets.firstWhere((w) => w.id == wallet.id, orElse: () => wallet);
    final String oldName = oldWallet.name;
    final String newName = wallet.name;

    await DatabaseHelper.instance.update('wallets', wallet.toMap());
    await fetchWallets();

    if (oldName.isNotEmpty && oldName != newName) {
      await SyncService.renameTab(oldName, newName);
      await SyncService.updateWalletName(oldName, newName);
    }
  }

  Future<void> deleteWallet(int id) async {
    final wallet = _wallets.firstWhere((w) => w.id == id);
    if (wallet.isDefault) throw Exception("Cannot delete default wallet");

    final db = await DatabaseHelper.instance.database;
    final history = await db.query('transactions', where: 'walletId = ? OR toWalletId = ?', whereArgs: [id, id], limit: 1);
    
    if (history.isNotEmpty || wallet.balance > 0 || wallet.frozenAmount > 0) {
      // Archive instead of hard delete
      await db.update('wallets', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
    } else {
      await DatabaseHelper.instance.delete('wallets', id);
    }
    await fetchWallets();
  }

  // --- Category Methods ---
  Future<void> fetchCategories() async {
    final data = await DatabaseHelper.instance.queryAll('categories');
    _categories = data.map((e) => Category.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    await DatabaseHelper.instance.insert('categories', category.toMap());
    await fetchCategories();
  }

  Future<void> updateCategory(Category category) async {
    final oldCat = _categories.firstWhere((c) => c.id == category.id, orElse: () => category);
    final String oldName = oldCat.name;
    final String newName = category.name;

    final db = await DatabaseHelper.instance.database;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
    
    if (oldName != newName) {
      await db.update('transactions', {'title': newName}, where: 'categoryId = ?', whereArgs: [category.id]);
    }
    
    await fetchCategories();
    await fetchTransactions();

    if (oldName != newName) {
      await SyncService.updateCategoryName(oldName, newName);
    }
  }

  Future<void> deleteCategory(int id) async {
    final db = await DatabaseHelper.instance.database;
    final history = await db.query('transactions', where: 'categoryId = ?', whereArgs: [id], limit: 1);
    
    if (history.isNotEmpty) {
      await db.update('categories', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
    } else {
      await DatabaseHelper.instance.delete('categories', id);
    }
    await fetchCategories();
  }

  // --- Transaction Methods ---
  Future<void> fetchTransactions() async {
    final data = await DatabaseHelper.instance.queryAll('transactions');
    _transactions = data.map((e) => TransactionModel.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addIncome(double amount, int walletId, int categoryId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final db = await DatabaseHelper.instance.database;

    int id = 0;
    await db.transaction((txn) async {
      final cat = _categories.firstWhere((c) => c.id == categoryId);
      final tx = TransactionModel(
        title: cat.name,
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.income,
        walletId: walletId,
        categoryId: categoryId,
      );
      id = await txn.insert('transactions', tx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);
    });

    await fetchTransactions();
    await fetchWallets();
    _triggerSync(id);
  }

  Future<void> addExpense(double amount, int walletId, int categoryId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int id = 0;
    await db.transaction((txn) async {
      final cat = _categories.firstWhere((c) => c.id == categoryId);
      final tx = TransactionModel(
        title: cat.name,
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.expense,
        walletId: walletId,
        categoryId: categoryId,
      );
      id = await txn.insert('transactions', tx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);
    });

    await fetchTransactions();
    await fetchWallets();
    _triggerSync(id);
  }

  Future<void> addTransfer(double amount, int fromWalletId, int toWalletId, DateTime date, String note) async {
    _validateAmount(amount);
    if (fromWalletId == toWalletId) throw Exception("Source and destination wallets must be different");
    await _ensureWalletActive(fromWalletId);
    await _ensureWalletActive(toWalletId);
    
    final fromWallet = _wallets.firstWhere((w) => w.id == fromWalletId);
    if (amount > fromWallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int id = 0;
    await db.transaction((txn) async {
      final tx = TransactionModel(
        title: 'Transfer',
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.transfer,
        walletId: fromWalletId,
        toWalletId: toWalletId,
      );
      id = await txn.insert('transactions', tx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, fromWalletId]);
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, toWalletId]);
    });

    await fetchTransactions();
    await fetchWallets();
    _triggerSync(id);
  }

  // --- Loan Methods ---
  Future<void> fetchLoans() async {
    final recipients = await DatabaseHelper.instance.queryAll('loan_recipients');
    _loanRecipients = recipients.map((e) => LoanRecipient.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> fetchLoanTransactions() async {
    final data = await DatabaseHelper.instance.queryAll('loan_transactions');
    _loanTransactions = data.map((e) => LoanTransaction.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> giveLoan(String recipientName, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'loan_recipients',
        where: 'name = ? AND isDebt = ?',
        whereArgs: [recipientName, 0],
      );

      int recipientId;
      if (existing.isEmpty) {
        recipientId = await txn.insert('loan_recipients', {
          'name': recipientName,
          'totalAmount': amount,
          'isDebt': 0,
        });
      } else {
        recipientId = existing.first['id'];
        await txn.execute(
          'UPDATE loan_recipients SET totalAmount = totalAmount + ? WHERE id = ?',
          [amount, recipientId],
        );
      }

      final ltx = LoanTransaction(
        recipientId: recipientId,
        amount: amount,
        type: LoanTransactionType.give,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('loan_transactions', ltx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: existing.isEmpty ? "Loan Given · $recipientName" : "More Loan Given · $recipientName",
        amount: amount,
        date: date,
        note: note,
        type: existing.isEmpty ? TransactionType.loanGiven : TransactionType.loanGivenMore,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });
    
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> recoverLoan(int recipientId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    
    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> recs = await txn.query('loan_recipients', where: 'id = ?', whereArgs: [recipientId]);
      if (recs.isEmpty) throw Exception("Recipient not found");
      final double outstanding = (recs.first['totalAmount'] as num).toDouble();
      if (amount > outstanding) throw Exception("Recovery amount exceeds outstanding balance");

      final String name = recs.first['name'];

      await txn.execute(
        'UPDATE loan_recipients SET totalAmount = totalAmount - ? WHERE id = ?',
        [amount, recipientId],
      );

      final ltx = LoanTransaction(
        recipientId: recipientId,
        amount: amount,
        type: LoanTransactionType.recover,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('loan_transactions', ltx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "Loan Recovered · $name",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.loanRecovered,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> giveMoreLoan(int recipientId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> recs = await txn.query('loan_recipients', where: 'id = ?', whereArgs: [recipientId]);
      if (recs.isEmpty) throw Exception("Recipient not found");
      final String name = recs.first['name'];

      await txn.execute(
        'UPDATE loan_recipients SET totalAmount = totalAmount + ? WHERE id = ?',
        [amount, recipientId],
      );

      final ltx = LoanTransaction(
        recipientId: recipientId,
        amount: amount,
        type: LoanTransactionType.give,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('loan_transactions', ltx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "More Loan Given · $name",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.loanGivenMore,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });
    
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> takeLoan(String providerName, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'loan_recipients',
        where: 'name = ? AND isDebt = ?',
        whereArgs: [providerName, 1],
      );

      int recipientId;
      if (existing.isEmpty) {
        recipientId = await txn.insert('loan_recipients', {
          'name': providerName,
          'totalAmount': amount,
          'isDebt': 1,
        });
      } else {
        recipientId = existing.first['id'];
        await txn.execute(
          'UPDATE loan_recipients SET totalAmount = totalAmount + ? WHERE id = ?',
          [amount, recipientId],
        );
      }

      final ltx = LoanTransaction(
        recipientId: recipientId,
        amount: amount,
        type: LoanTransactionType.take,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('loan_transactions', ltx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: existing.isEmpty ? "Loan Taken · $providerName" : "More Loan Taken · $providerName",
        amount: amount,
        date: date,
        note: note,
        type: existing.isEmpty ? TransactionType.loanTaken : TransactionType.loanTakenMore,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });
    
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> repayLoan(int recipientId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> recs = await txn.query('loan_recipients', where: 'id = ?', whereArgs: [recipientId]);
      if (recs.isEmpty) throw Exception("Recipient not found");
      final double outstanding = (recs.first['totalAmount'] as num).toDouble();
      if (amount > outstanding) throw Exception("Repayment amount exceeds outstanding balance");

      final String name = recs.first['name'];

      await txn.execute(
        'UPDATE loan_recipients SET totalAmount = totalAmount - ? WHERE id = ?',
        [amount, recipientId],
      );

      final ltx = LoanTransaction(
        recipientId: recipientId,
        amount: amount,
        type: LoanTransactionType.repay,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('loan_transactions', ltx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "Loan Repaid · $name",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.loanRepaid,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<int?> _getOrCreateCategoryIdInTx(Transaction txn, String name, TransactionType type) async {
    final List<Map<String, dynamic>> cats = await txn.query('categories', where: 'name = ?', whereArgs: [name]);
    if (cats.isNotEmpty) return cats.first['id'];
    
    return await txn.insert('categories', {
      'name': name,
      'iconCode': name == 'Loan' ? 0xf276 : (name == 'Savings' ? 0xe581 : 0xe0b2),
      'type': type == TransactionType.income || type == TransactionType.loanRecovered || type == TransactionType.investmentProfit || type == TransactionType.loanTaken
          ? 'income' : 'expense',
      'is_archived': 0
    });
  }

  Future<void> deleteLoanRecipient(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('loan_transactions', where: 'recipientId = ?', whereArgs: [id]);
    await db.delete('loan_recipients', where: 'id = ?', whereArgs: [id]);
    await fetchLoans();
    await fetchLoanTransactions();
  }

  // --- Investment Methods ---
  Future<void> fetchInvestments() async {
    final data = await DatabaseHelper.instance.queryAll('investments');
    _investments = data.map((e) => Investment.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> fetchInvestmentTransactions() async {
    final data = await DatabaseHelper.instance.queryAll('investment_transactions');
    _investmentTransactions = data.map((e) => InvestmentTransaction.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addInvestment(String title, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final investmentId = await txn.insert('investments', {
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      });

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.invest,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('investment_transactions', invTx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "Investment: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.investmentCreated,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });
    
    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    SyncService.createTab(title);
    _triggerSync(gtxId);
  }

  Future<void> moreInvest(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];

      await txn.execute('UPDATE investments SET amount = amount + ? WHERE id = ?', [amount, investmentId]);

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.invest,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('investment_transactions', invTx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "Investment: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.investmentIncreased,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> withdrawInvestment(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];
      double currentAmount = (invs.first['amount'] as num).toDouble();
      if (amount > currentAmount) throw Exception("Withdrawal amount exceeds investment balance");

      await txn.execute('UPDATE investments SET amount = amount - ? WHERE id = ?', [amount, investmentId]);

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.withdraw,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('investment_transactions', invTx.toMap());
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "Investment: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.investmentWithdraw,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> addInvestmentProfit(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      String title = invs.first['title'];

      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);

      final gtx = TransactionModel(
        title: "Investment: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.investmentProfit,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.profit,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('investment_transactions', invTx.toMap());
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> adjustInvestmentFromWallet(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];

      // Deduct from wallet's withdrawable balance (Investment principal unchanged)
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.expense,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('investment_transactions', invTx.toMap());

      final gtx = TransactionModel(
        title: "Investment: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.investmentExpense,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> adjustInvestmentFromPrincipal(int investmentId, double amount, DateTime date, String note) async {
    _validateAmount(amount);

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];
      double currentAmount = (invs.first['amount'] as num).toDouble();
      if (amount > currentAmount) throw Exception("Adjustment amount exceeds investment remaining principal");

      // Deduct directly from investment principal (Wallet balance unchanged)
      await txn.execute('UPDATE investments SET amount = amount - ? WHERE id = ?', [amount, investmentId]);

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.adjustment,
        walletId: 0,
        date: date,
        note: note,
      );
      await txn.insert('investment_transactions', invTx.toMap());

      final gtx = TransactionModel(
        title: "Investment: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.investmentAdjustment,
        walletId: 0,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> deleteInvestment(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('investment_transactions', where: 'investmentId = ?', whereArgs: [id]);
    await db.delete('investments', where: 'id = ?', whereArgs: [id]);
    await fetchInvestments();
    await fetchInvestmentTransactions();
  }

  // --- Savings Methods ---
  Future<void> fetchSavings() async {
    final data = await DatabaseHelper.instance.queryAll('savings');
    _savings = data.map((e) => Savings.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> fetchSavingsTransactions() async {
    final data = await DatabaseHelper.instance.queryAll('savings_transactions');
    _savingsTransactions = data.map((e) => SavingsTransaction.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addSavings(String title, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final savingsId = await txn.insert('savings', {
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      });

      final stx = SavingsTransaction(
        savingsId: savingsId,
        amount: amount,
        type: SavingsTransactionType.deposit,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('savings_transactions', stx.toMap());
      
      // Update wallet balances
      await txn.execute('UPDATE wallets SET balance = balance - ?, frozen_amount = frozen_amount + ? WHERE id = ?', [amount, amount, walletId]);
      
      // Update allocation
      await txn.insert('savings_allocations', {'savingsId': savingsId, 'walletId': walletId, 'amount': amount});

      final gtx = TransactionModel(
        title: "Savings: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.savingsCreated,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchWallets();
    await fetchTransactions();
    SyncService.createTab(title);
    _triggerSync(gtxId);
  }

  Future<void> depositToSavings(int savingsId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> savs = await txn.query('savings', where: 'id = ?', whereArgs: [savingsId]);
      if (savs.isEmpty) throw Exception("Savings goal not found");
      String title = savs.first['title'];

      await txn.execute('UPDATE savings SET amount = amount + ? WHERE id = ?', [amount, savingsId]);

      final stx = SavingsTransaction(
        savingsId: savingsId,
        amount: amount,
        type: SavingsTransactionType.deposit,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('savings_transactions', stx.toMap());
      
      await txn.execute('UPDATE wallets SET balance = balance - ?, frozen_amount = frozen_amount + ? WHERE id = ?', [amount, amount, walletId]);
      
      // Update or insert allocation
      final List<Map<String, dynamic>> alloc = await txn.query('savings_allocations', where: 'savingsId = ? AND walletId = ?', whereArgs: [savingsId, walletId]);
      if (alloc.isEmpty) {
        await txn.insert('savings_allocations', {'savingsId': savingsId, 'walletId': walletId, 'amount': amount});
      } else {
        await txn.execute('UPDATE savings_allocations SET amount = amount + ? WHERE savingsId = ? AND walletId = ?', [amount, savingsId, walletId]);
      }

      final gtx = TransactionModel(
        title: "Savings: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.savingsIncreased,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> withdrawFromSavings(int savingsId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    int gtxId = 0;
    await db.transaction((txn) async {
      // Check allocation for this specific wallet and goal
      final List<Map<String, dynamic>> alloc = await txn.query('savings_allocations', where: 'savingsId = ? AND walletId = ?', whereArgs: [savingsId, walletId]);
      if (alloc.isEmpty) throw Exception("No savings allocation for this goal in selected wallet");
      final double walletAllocation = (alloc.first['amount'] as num).toDouble();
      if (amount > walletAllocation) throw Exception("Withdrawal amount exceeds wallet's frozen allocation for this goal");

      final List<Map<String, dynamic>> savs = await txn.query('savings', where: 'id = ?', whereArgs: [savingsId]);
      if (savs.isEmpty) throw Exception("Savings goal not found");
      final String title = savs.first['title'];

      await txn.execute('UPDATE savings SET amount = amount - ? WHERE id = ?', [amount, savingsId]);

      final stx = SavingsTransaction(
        savingsId: savingsId,
        amount: amount,
        type: SavingsTransactionType.withdraw,
        walletId: walletId,
        date: date,
        note: note,
      );
      await txn.insert('savings_transactions', stx.toMap());
      
      await txn.execute('UPDATE wallets SET balance = balance + ?, frozen_amount = frozen_amount - ? WHERE id = ?', [amount, amount, walletId]);
      
      await txn.execute('UPDATE savings_allocations SET amount = amount - ? WHERE savingsId = ? AND walletId = ?', [amount, savingsId, walletId]);

      final gtx = TransactionModel(
        title: "Savings: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.savingsWithdrawal,
        walletId: walletId,
        categoryId: null,
      );
      gtxId = await txn.insert('transactions', gtx.toMap());
    });

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchWallets();
    await fetchTransactions();
    _triggerSync(gtxId);
  }

  Future<void> deleteSavings(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('savings_transactions', where: 'savingsId = ?', whereArgs: [id]);
    await db.delete('savings', where: 'id = ?', whereArgs: [id]);
    await fetchSavings();
    await fetchSavingsTransactions();
  }

  Future<List<Wallet>> getWalletsForSavings(int savingsId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> data = await db.query(
      'savings_allocations',
      where: 'savingsId = ? AND amount > 0',
      whereArgs: [savingsId],
    );
    
    final walletIds = data.map((e) => e['walletId'] as int).toList();
    return _wallets.where((w) => walletIds.contains(w.id)).toList();
  }

  Future<double> getSavingsAllocationForWallet(int savingsId, int walletId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> data = await db.query(
      'savings_allocations',
      where: 'savingsId = ? AND walletId = ?',
      whereArgs: [savingsId, walletId],
    );
    if (data.isEmpty) return 0.0;
    return (data.first['amount'] as num).toDouble();
  }

  Future<void> updateLoanRecipientName(int id, String newName) async {
    final rec = _loanRecipients.firstWhere((r) => r.id == id, orElse: () => LoanRecipient(id: id, name: '', totalAmount: 0, isDebt: false));
    final String oldName = rec.name;

    final db = await DatabaseHelper.instance.database;
    await db.update('loan_recipients', {'name': newName}, where: 'id = ?', whereArgs: [id]);

    if (oldName.isNotEmpty && oldName != newName) {
      await db.execute("UPDATE transactions SET title = ? WHERE title LIKE ?", ["Loan Given · $newName", "%Given · $oldName"]);
      await db.execute("UPDATE transactions SET title = ? WHERE title LIKE ?", ["Loan Recovered · $newName", "%Recovered · $oldName"]);
      await db.execute("UPDATE transactions SET title = ? WHERE title LIKE ?", ["Loan Taken · $newName", "%Taken · $oldName"]);
      await db.execute("UPDATE transactions SET title = ? WHERE title LIKE ?", ["Loan Repaid · $newName", "%Repaid · $oldName"]);
    }

    await fetchLoans();
    await fetchTransactions();

    if (oldName.isNotEmpty && oldName != newName) {
      await SyncService.updateCategoryName(oldName, newName);
    }
  }

  Future<void> updateInvestmentTitle(int id, String newTitle) async {
    final inv = _investments.firstWhere((i) => i.id == id, orElse: () => Investment(id: id, title: '', amount: 0, date: DateTime.now(), note: ''));
    final String oldTitle = inv.title;

    final db = await DatabaseHelper.instance.database;
    await db.update('investments', {'title': newTitle}, where: 'id = ?', whereArgs: [id]);

    if (oldTitle.isNotEmpty && oldTitle != newTitle) {
      await db.execute("UPDATE transactions SET title = ? WHERE title = ?", ["Investment: $newTitle", "Investment: $oldTitle"]);
    }

    await fetchInvestments();
    await fetchTransactions();

    if (oldTitle.isNotEmpty && oldTitle != newTitle) {
      await SyncService.renameTab(oldTitle, newTitle);
      await SyncService.updateCategoryName(oldTitle, newTitle);
    }
  }

  Future<void> updateSavingsTitle(int id, String newTitle) async {
    final sav = _savings.firstWhere((s) => s.id == id, orElse: () => Savings(id: id, title: '', amount: 0, date: DateTime.now(), note: ''));
    final String oldTitle = sav.title;

    final db = await DatabaseHelper.instance.database;
    await db.update('savings', {'title': newTitle}, where: 'id = ?', whereArgs: [id]);

    if (oldTitle.isNotEmpty && oldTitle != newTitle) {
      await db.execute("UPDATE transactions SET title = ? WHERE title = ?", ["Savings: $newTitle", "Savings: $oldTitle"]);
    }

    await fetchSavings();
    await fetchTransactions();

    if (oldTitle.isNotEmpty && oldTitle != newTitle) {
      await SyncService.renameTab(oldTitle, newTitle);
      await SyncService.updateCategoryName(oldTitle, newTitle);
    }
  }

  // --- Financial Summaries (Rules Based) ---
  
  double get totalWalletAssets {
    // Rule: Wallet Asset = Withdrawable + Frozen
    return _wallets.fold(0, (sum, w) => sum + w.balance + w.frozenAmount);
  }

  double get totalLoanReceivable {
    // Rule: Assets include Given Loan Receivables (isDebt = 0)
    return _loanRecipients
        .where((r) => !r.isDebt)
        .fold(0, (sum, r) => sum + r.totalAmount);
  }

  double get totalLoanPayable {
    // Rule: Liabilities include Taken Loans (isDebt = 1)
    return _loanRecipients
        .where((r) => r.isDebt)
        .fold(0, (sum, r) => sum + r.totalAmount);
  }

  double get totalInvestments {
    // Rule: Assets include Investments
    return _investments.fold(0, (sum, i) => sum + i.amount);
  }

  double get totalAssets {
    return totalWalletAssets + totalLoanReceivable + totalInvestments;
  }

  double get totalLiabilities {
    return totalLoanPayable;
  }

  double get netWorth {
    // Rule: Net Worth = Total Assets - Total Liabilities
    return totalAssets - totalLiabilities;
  }

  // --- Reporting Methods ---

  double get totalIncome {
    // Rule: Only Add Money and Investment Profit create Income
    return _transactions
        .where((tx) => tx.type == TransactionType.income || tx.type == TransactionType.investmentProfit)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double get totalExpense {
    // Rule: Only Add Expense creates Expense
    return _transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double get lastWeekExpense {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    int daysSinceStart = (todayStart.weekday - _weekStartDay) % 7;
    if (daysSinceStart < 0) daysSinceStart += 7;

    final thisWeekStart = todayStart.subtract(Duration(days: daysSinceStart));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(seconds: 1));

    return _transactions
        .where((tx) => 
            tx.type == TransactionType.expense && 
            (tx.date.isAfter(lastWeekStart.subtract(const Duration(seconds: 1))) && 
             tx.date.isBefore(lastWeekEnd.add(const Duration(seconds: 1)))))
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double get thisWeekExpense {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    int daysSinceStart = (todayStart.weekday - _weekStartDay) % 7;
    if (daysSinceStart < 0) daysSinceStart += 7;

    final thisWeekStart = todayStart.subtract(Duration(days: daysSinceStart));

    return _transactions
        .where((tx) => 
            tx.type == TransactionType.expense && 
            (tx.date.isAfter(thisWeekStart.subtract(const Duration(seconds: 1))) && 
             tx.date.isBefore(todayEnd.add(const Duration(seconds: 1)))))
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  Future<void> resetApp() async {
    // 1. Clear Google Sheet Data
    await SyncService.resetSheet();
    
    // 2. Clear Local Database
    await DatabaseHelper.instance.resetDatabase();
    
    // 3. Refresh Provider State
    await fetchAll();

    // 4. Sync Default Wallet to Sheet
    if (_wallets.isNotEmpty) {
      final defaultWallet = _wallets.firstWhere((w) => w.isDefault, orElse: () => _wallets.first);
      _triggerWalletSync(defaultWallet);
    }
  }

  Future<void> syncFromSheet() async {
    final data = await SyncService.fetchFromSheet();
    if (data.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (var row in data) {
        // 1. Get or Create Wallet ID (Skip non-wallet identifiers)
        String walletName = row['walletName']?.toString() ?? 'Default';
        int walletId = 0;
        if (walletName != 'N/A' && walletName != 'Investment Principal' && walletName != 'None' && walletName.isNotEmpty) {
          walletId = await _getOrCreateWalletIdInTx(txn, walletName);
        }

        // 2. Map Label back to Type
        String typeLabel = row['transectionType']?.toString() ?? 'Expense';
        TransactionType type = _getTypeFromLabel(typeLabel);
        
        // 2b. Extract titleCategory early (needed for transfer parsing)
        String titleCategory = row['titleCategory']?.toString() ?? 'General';
        
        // 2c. Parse toWalletId for transfers from titleCategory ("To WalletName" / "From WalletName")
        int? toWalletId;
        if (type == TransactionType.transfer && titleCategory.isNotEmpty) {
          String? otherWalletName;
          if (titleCategory.startsWith('To ')) {
            otherWalletName = titleCategory.substring(3);
          } else if (titleCategory.startsWith('From ')) {
            otherWalletName = titleCategory.substring(5);
          }
          
          if (otherWalletName != null && otherWalletName.isNotEmpty && otherWalletName != walletName) {
            toWalletId = await _getOrCreateWalletIdInTx(txn, otherWalletName);
          }
        }
        
        // 3. Category & Entity handling
        int? categoryId;
        if (type == TransactionType.income || type == TransactionType.expense) {
          categoryId = await _getOrCreateCategoryIdInTx(txn, titleCategory, type);
        } else if (titleCategory.isNotEmpty && titleCategory != 'General') {
          if (_isInvestmentTx(type)) {
            final exists = (await txn.query('investments', where: 'title = ?', whereArgs: [titleCategory])).isNotEmpty;
            if (!exists) {
              await txn.insert('investments', {
                'title': titleCategory,
                'amount': 0.0,
                'date': _parseSheetDate(row['date']?.toString()),
                'note': 'Synced from Sheet',
              });
            }
          } else if (_isSavingsTx(type)) {
            final exists = (await txn.query('savings', where: 'title = ?', whereArgs: [titleCategory])).isNotEmpty;
            if (!exists) {
              await txn.insert('savings', {
                'title': titleCategory,
                'amount': 0.0,
                'date': _parseSheetDate(row['date']?.toString()),
                'note': 'Synced from Sheet',
              });
            }
          } else if (_isLoanTx(type)) {
            bool isDebt = type == TransactionType.loanTaken || type == TransactionType.loanTakenMore || type == TransactionType.loanRepaid;
            final exists = (await txn.query('loan_recipients', where: 'name = ? AND isDebt = ?', whereArgs: [titleCategory, isDebt ? 1 : 0])).isNotEmpty;
            if (!exists) {
              await txn.insert('loan_recipients', {
                'name': titleCategory,
                'totalAmount': 0.0,
                'isDebt': isDebt ? 1 : 0,
              });
            }
          }
        }

        // 4. Map Transaction
        final txMap = {
          'id': int.tryParse(row['id'].toString()),
          'title': titleCategory,
          'amount': double.tryParse(row['amount'].toString()) ?? 0.0,
          'date': _parseSheetDate(row['date']?.toString()),
          'note': row['note']?.toString() ?? '',
          'type': type.name,
          'walletId': walletId,
          'toWalletId': toWalletId,
          'categoryId': categoryId,
        };
        
        if (txMap['id'] != null) {
          await txn.insert('transactions', txMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await _recalculateWalletBalancesInTx(txn);
    });
    await fetchAll();
  }

  Future<void> _recalculateWalletBalancesInTx(Transaction txn) async {
    final List<Map<String, dynamic>> walletRows = await txn.query('wallets');
    final List<Map<String, dynamic>> txRows = await txn.query('transactions');

    for (var w in walletRows) {
      int wId = w['id'];
      double calculatedBalance = 0.0;
      double calculatedFrozen = 0.0;

      for (var txMap in txRows) {
        int? walletId = txMap['walletId'];
        int? toWalletId = txMap['toWalletId'];
        double amount = (txMap['amount'] as num).toDouble();
        TransactionType type = TransactionType.values.byName(txMap['type']);

        if (walletId == wId) {
          switch (type) {
            case TransactionType.income:
            case TransactionType.investmentProfit:
            case TransactionType.investmentWithdraw:
            case TransactionType.loanRecovered:
            case TransactionType.loanTaken:
            case TransactionType.loanTakenMore:
              calculatedBalance += amount;
              break;
            case TransactionType.expense:
            case TransactionType.transfer:
            case TransactionType.loanGiven:
            case TransactionType.loanGivenMore:
            case TransactionType.loanRepaid:
            case TransactionType.investmentCreated:
            case TransactionType.investmentIncreased:
            case TransactionType.investmentExpense:
              calculatedBalance -= amount;
              break;
            case TransactionType.savingsCreated:
            case TransactionType.savingsIncreased:
              calculatedBalance -= amount;
              calculatedFrozen += amount;
              break;
            case TransactionType.savingsWithdrawal:
              calculatedBalance += amount;
              calculatedFrozen -= amount;
              break;
            case TransactionType.investmentAdjustment:
              break;
          }
        }

        if (toWalletId == wId && type == TransactionType.transfer) {
          calculatedBalance += amount;
        }
      }

      await txn.execute(
        'UPDATE wallets SET balance = ?, frozen_amount = ? WHERE id = ?',
        [calculatedBalance, calculatedFrozen < 0 ? 0.0 : calculatedFrozen, wId],
      );
    }
  }

  TransactionType _getTypeFromLabel(String label) {
    final String clean = label.trim();
    switch (clean) {
      case "Money Added":
      case "Income":
      case "income":
        return TransactionType.income;
      case "Expense":
      case "expense":
      case "expanse":
        return TransactionType.expense;
      case "Transferred":
      case "transfer":
        return TransactionType.transfer;
      case "Loan Given":
      case "loan given":
        return TransactionType.loanGiven;
      case "More Loan Given":
        return TransactionType.loanGivenMore;
      case "Loan Recovered":
      case "loan recovered":
        return TransactionType.loanRecovered;
      case "Loan Taken":
      case "loan taken":
        return TransactionType.loanTaken;
      case "More Loan Taken":
        return TransactionType.loanTakenMore;
      case "Loan Repaid":
      case "loan repaid":
        return TransactionType.loanRepaid;
      case "investmentCreated":
      case "Investment Created":
        return TransactionType.investmentCreated;
      case "Investment Increased":
        return TransactionType.investmentIncreased;
      case "Profit Added":
        return TransactionType.investmentProfit;
      case "Investment Withdraw":
        return TransactionType.investmentWithdraw;
      case "investment Expanse":
      case "Investment Expense":
        return TransactionType.investmentExpense;
      case "Investment Adjustment":
        return TransactionType.investmentAdjustment;
      case "Savings Created":
        return TransactionType.savingsCreated;
      case "Savings Increased":
        return TransactionType.savingsIncreased;
      case "Savings Withdraw":
      case "Savings Withdrawal":
        return TransactionType.savingsWithdrawal;
      default:
        return TransactionType.expense;
    }
  }

  Future<int> _getOrCreateWalletIdInTx(Transaction txn, String name) async {
    final List<Map<String, dynamic>> res = await txn.query('wallets', where: 'name = ?', whereArgs: [name]);
    if (res.isNotEmpty) return res.first['id'];
    return await txn.insert('wallets', {
      'name': name,
      'balance': 0.0,
      'frozen_amount': 0.0,
      'color': 0xFF2196F3,
      'isDefault': 0,
      'is_archived': 0
    });
  }

  void _triggerSync(int txId) {
    try {
      final savedTx = _transactions.firstWhere((t) => t.id == txId);
      
      if (savedTx.type == TransactionType.transfer && savedTx.toWalletId != null) {
        final fromWallet = _wallets.firstWhere((w) => w.id == savedTx.walletId);
        final toWallet = _wallets.firstWhere((w) => w.id == savedTx.toWalletId);
        
        // 1. Sync for Source Wallet (Outgoing)
        SyncService.syncTransaction(
          savedTx, 
          fromWallet.name, 
          "To ${toWallet.name}", 
          _getTransectionTypeLabel(savedTx.type)
        );
        
        // 2. Sync for Target Wallet (Incoming)
        SyncService.syncTransaction(
          savedTx, 
          toWallet.name, 
          "From ${fromWallet.name}", 
          _getTransectionTypeLabel(savedTx.type)
        );
      } else {
        String walletName = "N/A";
        if (savedTx.walletId != 0) {
          final wallet = _wallets.firstWhere((w) => w.id == savedTx.walletId, orElse: () => _wallets.first);
          walletName = wallet.name;
        }

        String titleCategory = "";
        String? secondaryTabName;
        
        if (savedTx.categoryId != null) {
          titleCategory = _categories.firstWhere(
            (c) => c.id == savedTx.categoryId, 
            orElse: () => Category(name: 'General', iconCode: 0, type: CategoryType.expense)
          ).name;
        } else {
          titleCategory = _extractName(savedTx.title);

          if (_isInvestmentTx(savedTx.type)) {
            secondaryTabName = titleCategory;
            if (savedTx.walletId == 0) {
              // Direct Principal Adjustment - no wallet involved
              walletName = "N/A";
            }
          } else if (_isSavingsTx(savedTx.type)) {
            secondaryTabName = titleCategory;
          } else if (_isLoanTx(savedTx.type)) {
            secondaryTabName = "Loans";
          }
        }

        SyncService.syncTransaction(
          savedTx, 
          walletName, 
          titleCategory, 
          _getTransectionTypeLabel(savedTx.type),
          secondaryTabName: secondaryTabName,
        );
      }
    } catch (e) {
      print("Sync trigger error: $e");
    }
  }

  bool _isInvestmentTx(TransactionType type) {
    return type == TransactionType.investmentCreated ||
        type == TransactionType.investmentIncreased ||
        type == TransactionType.investmentProfit ||
        type == TransactionType.investmentWithdraw ||
        type == TransactionType.investmentExpense ||
        type == TransactionType.investmentAdjustment;
  }

  bool _isSavingsTx(TransactionType type) {
    return type == TransactionType.savingsCreated ||
        type == TransactionType.savingsIncreased ||
        type == TransactionType.savingsWithdrawal;
  }

  bool _isLoanTx(TransactionType type) {
    return type == TransactionType.loanGiven ||
        type == TransactionType.loanGivenMore ||
        type == TransactionType.loanRecovered ||
        type == TransactionType.loanTaken ||
        type == TransactionType.loanTakenMore ||
        type == TransactionType.loanRepaid;
  }

  String _getTransectionTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income: return "Money Added";
      case TransactionType.expense: return "Expense";
      case TransactionType.transfer: return "Transferred";
      case TransactionType.loanGiven: return "Loan Given";
      case TransactionType.loanGivenMore: return "More Loan Given";
      case TransactionType.loanRecovered: return "Loan Recovered";
      case TransactionType.loanTaken: return "Loan Taken";
      case TransactionType.loanTakenMore: return "More Loan Taken";
      case TransactionType.loanRepaid: return "Loan Repaid";
      case TransactionType.investmentCreated: return "investmentCreated";
      case TransactionType.investmentIncreased: return "Investment Increased";
      case TransactionType.investmentProfit: return "Profit Added";
      case TransactionType.investmentWithdraw: return "Investment Withdraw";
      case TransactionType.investmentExpense: return "investment Expanse";
      case TransactionType.investmentAdjustment: return "Investment Adjustment";
      case TransactionType.savingsCreated: return "Savings Created";
      case TransactionType.savingsIncreased: return "Savings Increased";
      case TransactionType.savingsWithdrawal: return "Savings Withdraw";
    }
  }

  String _extractName(String fullTitle) {
    if (fullTitle.contains(': ')) return fullTitle.split(': ').last;
    if (fullTitle.contains('· ')) return fullTitle.split('· ').last;
    return fullTitle;
  }

  String _parseSheetDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now().toIso8601String();
    try {
      String s = raw.trim();
      
      // Handle ISO strings with Z / T by parsing to LOCAL time first
      if (s.contains('T') || s.endsWith('Z')) {
        final localDt = DateTime.parse(s).toLocal();
        return DateTime(localDt.year, localDt.month, localDt.day, 12, 0, 0).toIso8601String();
      }

      if (s.contains('-') || s.contains('/')) {
        final separator = s.contains('-') ? '-' : '/';
        final parts = s.split(separator);
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            int year = int.parse(parts[0]);
            int month = int.parse(parts[1]);
            int day = int.parse(parts[2].replaceAll(RegExp(r'\D'), ''));
            return DateTime(year, month, day, 12, 0, 0).toIso8601String();
          } else {
            // DD-MM-YY or MM-DD-YY
            int p0 = int.parse(parts[0].replaceAll(RegExp(r'\D'), ''));
            int p1 = int.parse(parts[1].replaceAll(RegExp(r'\D'), ''));
            int year = int.parse(parts[2].replaceAll(RegExp(r'\D'), ''));
            if (year < 100) year += 2000;

            int day, month;
            if (p1 > 12) {
              // MM-DD-YY (e.g. 01-31-26)
              month = p0;
              day = p1;
            } else {
              // DD-MM-YY (e.g. 31-01-26)
              day = p0;
              month = p1;
            }
            return DateTime(year, month, day, 12, 0, 0).toIso8601String();
          }
        }
      }
      final parsed = DateTime.parse(s).toLocal();
      return DateTime(parsed.year, parsed.month, parsed.day, 12, 0, 0).toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }
}
