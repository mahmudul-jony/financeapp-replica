import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class FinanceProvider with ChangeNotifier, WidgetsBindingObserver {
  List<Wallet> _wallets = [];
  List<Category> _categories = [];
  List<TransactionModel> _transactions = [];
  List<LoanRecipient> _loanRecipients = [];
  List<LoanTransaction> _loanTransactions = [];
  List<Investment> _investments = [];
  List<InvestmentTransaction> _investmentTransactions = [];
  List<Savings> _savings = [];
  List<SavingsTransaction> _savingsTransactions = [];

  // Sync state
  bool _isSyncing = false;
  bool _syncRequestedAgain = false;
  String? _syncStatusMessage;
  DateTime? _lastSyncTime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;
  final List<String> _syncWarnings = [];
  final List<Map<String, dynamic>> _conflicts = [];

  bool get isSyncing => _isSyncing;
  String? get syncStatusMessage => _syncStatusMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<String> get syncWarnings => List.unmodifiable(_syncWarnings);
  List<Map<String, dynamic>> get conflicts => List.unmodifiable(_conflicts);
  bool get hasConflicts => _conflicts.isNotEmpty;
  bool get isOffline => _wasOffline;
  bool get isOnline => !_wasOffline;

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
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await fetchAll();
    try {
      final results = await Connectivity().checkConnectivity();
      _wasOffline = results.every((r) => r == ConnectivityResult.none);
    } catch (_) {}
    _initConnectivityListener();
    // Silent check on app startup only when online
    if (!_wasOffline) {
      silentSyncCheck();
    }
  }

  void _initConnectivityListener() {
    Connectivity().checkConnectivity().then((results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (_wasOffline != isOffline) {
        _wasOffline = isOffline;
        notifyListeners();
      }
    }).catchError((_) {});

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (_wasOffline && !isOffline) {
        // Connectivity returned while app remains open -> trigger silent sync check
        silentSyncCheck();
      }
      if (_wasOffline != isOffline) {
        _wasOffline = isOffline;
        notifyListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      silentSyncCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
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
  }

  Future<void> _ensureWalletActive(int walletId) async {
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (wallet.isArchived) throw Exception("Cannot perform transactions on an archived wallet");
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
    
    // Queue create tab for sheet
    final db = await DatabaseHelper.instance.database;
    await db.insert('sync_queue', {
      'entity_type': 'wallet',
      'entity_id': id.toString(),
      'action': 'create_tab',
      'payload': jsonEncode({'tabName': SyncService.walletTabName(wallet.name)}),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'last_error': null,
    });
    syncNow();

    if (wallet.balance > 0) {
      final defaultCat = _categories.firstWhere((c) => c.type == CategoryType.income, orElse: () => _categories.first);
      await addIncome(wallet.balance, savedWallet.id!, defaultCat.id!, DateTime.now(), "Initial Balance");
    }
  }


  Future<void> updateWallet(Wallet wallet) async {
    final oldWallet = _wallets.firstWhere((w) => w.id == wallet.id, orElse: () => wallet);
    final String oldName = oldWallet.name;
    final String newName = wallet.name;

    await DatabaseHelper.instance.update('wallets', wallet.toMap());
    await fetchWallets();

    if (oldName.isNotEmpty && oldName != newName) {
      final db = await DatabaseHelper.instance.database;
      await db.insert('sync_queue', {
        'entity_type': 'wallet',
        'entity_id': wallet.id.toString(),
        'action': 'rename_tab',
        'payload': jsonEncode({
          'oldTabName': SyncService.walletTabName(oldName),
          'newTabName': SyncService.walletTabName(newName),
        }),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      await db.insert('sync_queue', {
        'entity_type': 'wallet',
        'entity_id': wallet.id.toString(),
        'action': 'update_wallet_name',
        'payload': jsonEncode({'oldName': oldName, 'newName': newName}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      syncNow();
    }
  }

  Future<void> deleteWallet(int id) async {
    final wallet = _wallets.firstWhere((w) => w.id == id);
    if (wallet.isDefault) throw Exception("Cannot delete default wallet");

    final db = await DatabaseHelper.instance.database;
    final txs = await db.query('transactions', where: 'walletId = ? OR toWalletId = ?', whereArgs: [id, id]);

    // Delete all associated transactions from local SQLite
    await db.delete('transactions', where: 'walletId = ? OR toWalletId = ?', whereArgs: [id, id]);
    // Delete the wallet itself
    await DatabaseHelper.instance.delete('wallets', id);

    // Enqueue tab deletion in Google Sheet
    await db.insert('sync_queue', {
      'entity_type': 'wallet',
      'entity_id': id.toString(),
      'action': 'delete_tab',
      'payload': jsonEncode({'tabName': SyncService.walletTabName(wallet.name)}),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'last_error': null,
    });

    // Enqueue deletion of each associated transaction in Google Sheet
    for (var tx in txs) {
      final syncId = tx['sync_id']?.toString();
      if (syncId != null && syncId.isNotEmpty) {
        await db.insert('sync_queue', {
          'entity_type': 'transaction',
          'entity_id': syncId,
          'action': 'delete',
          'payload': jsonEncode({'id': syncId}),
          'created_at': DateTime.now().toIso8601String(),
          'retry_count': 0,
          'last_error': null,
        });
      }
    }

    await fetchWallets();
    await fetchTransactions();
    syncNow();
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
      await db.insert('sync_queue', {
        'entity_type': 'category',
        'entity_id': category.id.toString(),
        'action': 'update_category_name',
        'payload': jsonEncode({'oldName': oldName, 'newName': newName}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      syncNow();
    }
  }

  Future<void> deleteCategory(int id) async {
    final cat = _categories.firstWhere((c) => c.id == id, orElse: () => Category(id: id, name: '', iconCode: 0, type: CategoryType.expense));
    final catName = cat.name;

    final db = await DatabaseHelper.instance.database;
    // Category deletion rule: Retain all transactions, clear categoryId reference and set title to '-'
    await db.update('transactions', {'categoryId': null, 'title': '-'}, where: 'categoryId = ?', whereArgs: [id]);
    await DatabaseHelper.instance.delete('categories', id);
    await fetchCategories();
    await fetchTransactions();

    if (catName.isNotEmpty) {
      await db.insert('sync_queue', {
        'entity_type': 'category',
        'entity_id': id.toString(),
        'action': 'clear_category_name',
        'payload': jsonEncode({'categoryName': catName}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      syncNow();
    }
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

    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final now = DateTime.now();
    final tx = TransactionModel(
      title: cat.name,
      amount: amount,
      date: date,
      note: note,
      type: TransactionType.income,
      walletId: walletId,
      categoryId: categoryId,
      syncStatus: 'pending',
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);
      await _insertTransactionInTx(txn, tx);
    });

    await fetchTransactions();
    await fetchWallets();
    syncNow();
  }

  Future<void> addExpense(double amount, int walletId, int categoryId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final now = DateTime.now();
    final tx = TransactionModel(
      title: cat.name,
      amount: amount,
      date: date,
      note: note,
      type: TransactionType.expense,
      walletId: walletId,
      categoryId: categoryId,
      syncStatus: 'pending',
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);
      await _insertTransactionInTx(txn, tx);
    });

    await fetchTransactions();
    await fetchWallets();
    syncNow();
  }

  Future<void> addTransfer(double amount, int fromWalletId, int toWalletId, DateTime date, String note) async {
    _validateAmount(amount);
    if (fromWalletId == toWalletId) throw Exception("Source and destination wallets must be different");
    await _ensureWalletActive(fromWalletId);
    await _ensureWalletActive(toWalletId);
    
    final fromWallet = _wallets.firstWhere((w) => w.id == fromWalletId);
    if (amount > fromWallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final tx = TransactionModel(
      title: 'Transfer',
      amount: amount,
      date: date,
      note: note,
      type: TransactionType.transfer,
      walletId: fromWalletId,
      toWalletId: toWalletId,
      syncStatus: 'pending',
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.execute('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, fromWalletId]);
      await txn.execute('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, toWalletId]);
      await _insertTransactionInTx(txn, tx);
    });

    await fetchTransactions();
    await fetchWallets();
    syncNow();
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
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });
    
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> recoverLoan(int recipientId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> giveMoreLoan(int recipientId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });
    
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> takeLoan(String providerName, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });
    
    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> repayLoan(int recipientId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchLoans();
    await fetchLoanTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<int?> _getOrCreateCategoryIdInTx(Transaction txn, String name, TransactionType type) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final List<Map<String, dynamic>> cats = await txn.rawQuery(
      'SELECT * FROM categories WHERE LOWER(name) = LOWER(?)', [trimmed]
    );
    if (cats.isNotEmpty) return cats.first['id'] as int;
    
    return await txn.insert('categories', {
      'name': trimmed,
      'iconCode': trimmed == 'Loan' ? 0xf276 : (trimmed == 'Savings' ? 0xe581 : 0xe0b2),
      'type': type == TransactionType.income || type == TransactionType.loanRecovered || type == TransactionType.investmentProfit || type == TransactionType.loanTaken
          ? 'income' : 'expense',
      'is_archived': 0
    });
  }

  Future<void> deleteLoanRecipient(int id) async {
    final rec = _loanRecipients.firstWhere((r) => r.id == id, orElse: () => LoanRecipient(id: id, name: '', totalAmount: 0, isDebt: false));
    final db = await DatabaseHelper.instance.database;

    final txs = await db.query(
      'transactions',
      where: "title LIKE ? OR (type IN ('loanGiven', 'loanTaken', 'loanGivenMore', 'loanTakenMore', 'loanRecovered', 'loanRepaid') AND title LIKE ?)",
      whereArgs: ["% · ${rec.name}", "%${rec.name}%"],
    );

    await db.delete('loan_transactions', where: 'recipientId = ?', whereArgs: [id]);
    await db.delete('loan_recipients', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'transactions',
      where: "title LIKE ? OR (type IN ('loanGiven', 'loanTaken', 'loanGivenMore', 'loanTakenMore', 'loanRecovered', 'loanRepaid') AND title LIKE ?)",
      whereArgs: ["% · ${rec.name}", "%${rec.name}%"],
    );

    for (var tx in txs) {
      final syncId = tx['sync_id']?.toString();
      if (syncId != null && syncId.isNotEmpty) {
        await db.insert('sync_queue', {
          'entity_type': 'transaction',
          'entity_id': syncId,
          'action': 'delete',
          'payload': jsonEncode({'id': syncId}),
          'created_at': DateTime.now().toIso8601String(),
          'retry_count': 0,
          'last_error': null,
        });
      }
    }

    await fetchLoans();
    await fetchLoanTransactions();
    await fetchTransactions();
    await fetchWallets();
    syncNow();
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
    final now = DateTime.now();

    await db.transaction((txn) async {
      final invId = await txn.insert('investments', {
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      });

      final invTx = InvestmentTransaction(
        investmentId: invId,
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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
      
      // Enqueue create tab
      await txn.insert('sync_queue', {
        'entity_type': 'investment',
        'entity_id': invId.toString(),
        'action': 'create_tab',
        'payload': jsonEncode({'tabName': SyncService.investmentTabName(title)}),
        'created_at': now.toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
    });
    
    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> moreInvest(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> withdrawInvestment(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> addInvestmentProfit(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.profit,
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
        type: TransactionType.investmentProfit,
        walletId: walletId,
        categoryId: null,
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> adjustInvestmentFromWallet(int investmentId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.expense,
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
        type: TransactionType.investmentExpense,
        walletId: walletId,
        categoryId: null,
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> adjustInvestmentFromPrincipal(int investmentId, double amount, DateTime date, String note) async {
    _validateAmount(amount);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> invs = await txn.query('investments', where: 'id = ?', whereArgs: [investmentId]);
      if (invs.isEmpty) throw Exception("Investment not found");
      final String title = invs.first['title'];
      double currentAmount = (invs.first['amount'] as num).toDouble();
      if (amount > currentAmount) throw Exception("Expense amount exceeds investment principal balance");

      await txn.execute('UPDATE investments SET amount = amount - ? WHERE id = ?', [amount, investmentId]);

      final invTx = InvestmentTransaction(
        investmentId: investmentId,
        amount: amount,
        type: InvestmentTransactionType.expense,
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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchTransactions();
    syncNow();
  }

  Future<void> deleteInvestment(int id) async {
    final inv = _investments.firstWhere((i) => i.id == id, orElse: () => Investment(id: id, title: '', amount: 0, date: DateTime.now(), note: ''));
    final db = await DatabaseHelper.instance.database;

    final txs = await db.query(
      'transactions',
      where: "title LIKE ? OR (type IN ('investmentCreated', 'investmentIncreased', 'investmentProfit', 'investmentWithdraw', 'investmentExpense', 'investmentAdjustment') AND title LIKE ?)",
      whereArgs: ["Investment: ${inv.title}%", "%${inv.title}%"],
    );

    await db.delete('investment_transactions', where: 'investmentId = ?', whereArgs: [id]);
    await db.delete('investments', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'transactions',
      where: "title LIKE ? OR (type IN ('investmentCreated', 'investmentIncreased', 'investmentProfit', 'investmentWithdraw', 'investmentExpense', 'investmentAdjustment') AND title LIKE ?)",
      whereArgs: ["Investment: ${inv.title}%", "%${inv.title}%"],
    );

    if (inv.title.isNotEmpty) {
      await db.insert('sync_queue', {
        'entity_type': 'investment',
        'entity_id': id.toString(),
        'action': 'delete_tab',
        'payload': jsonEncode({'tabName': SyncService.investmentTabName(inv.title)}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });

      for (var tx in txs) {
        final syncId = tx['sync_id']?.toString();
        if (syncId != null && syncId.isNotEmpty) {
          await db.insert('sync_queue', {
            'entity_type': 'transaction',
            'entity_id': syncId,
            'action': 'delete',
            'payload': jsonEncode({'id': syncId}),
            'created_at': DateTime.now().toIso8601String(),
            'retry_count': 0,
            'last_error': null,
          });
        }
      }
    }

    await fetchInvestments();
    await fetchInvestmentTransactions();
    await fetchTransactions();
    await fetchWallets();
    syncNow();
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
    final now = DateTime.now();

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

      await txn.execute('UPDATE wallets SET balance = balance - ?, frozen_amount = frozen_amount + ? WHERE id = ?', [amount, amount, walletId]);
      await txn.insert('savings_allocations', {'savingsId': savingsId, 'walletId': walletId, 'amount': amount});

      final gtx = TransactionModel(
        title: "Savings: $title",
        amount: amount,
        date: date,
        note: note,
        type: TransactionType.savingsCreated,
        walletId: walletId,
        categoryId: null,
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
      
      // Enqueue create tab
      await txn.insert('sync_queue', {
        'entity_type': 'savings',
        'entity_id': savingsId.toString(),
        'action': 'create_tab',
        'payload': jsonEncode({'tabName': SyncService.savingsTabName(title)}),
        'created_at': now.toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
    });

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> depositToSavings(int savingsId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    if (amount > wallet.balance) throw Exception("Insufficient withdrawable balance");

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> withdrawFromSavings(int savingsId, double amount, int walletId, DateTime date, String note) async {
    _validateAmount(amount);
    await _ensureWalletActive(walletId);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // Check allocation for this specific wallet and goal
      final List<Map<String, dynamic>> alloc = await txn.query('savings_allocations', where: 'savingsId = ? AND walletId = ?', whereArgs: [savingsId, walletId]);
      if (alloc.isEmpty) throw Exception("No savings allocation for this goal in selected wallet");
      final double currentAlloc = (alloc.first['amount'] as num).toDouble();
      if (amount > currentAlloc) throw Exception("Withdrawal exceeds goal's allocated frozen balance for this wallet");

      final List<Map<String, dynamic>> savs = await txn.query('savings', where: 'id = ?', whereArgs: [savingsId]);
      if (savs.isEmpty) throw Exception("Savings goal not found");
      String title = savs.first['title'];

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
        syncStatus: 'pending',
        updatedAt: now,
      );
      await _insertTransactionInTx(txn, gtx);
    });

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchWallets();
    await fetchTransactions();
    syncNow();
  }

  Future<void> deleteSavings(int id) async {
    final sav = _savings.firstWhere((s) => s.id == id, orElse: () => Savings(id: id, title: '', amount: 0, date: DateTime.now(), note: ''));
    final db = await DatabaseHelper.instance.database;

    // Restore frozen amounts in wallets
    final allocs = await db.query('savings_allocations', where: 'savingsId = ?', whereArgs: [id]);
    for (var a in allocs) {
      final wId = a['walletId'] as int;
      final amt = (a['amount'] as num).toDouble();
      if (amt > 0) {
        await db.execute('UPDATE wallets SET balance = balance + ?, frozen_amount = frozen_amount - ? WHERE id = ?', [amt, amt, wId]);
      }
    }

    final txs = await db.query(
      'transactions',
      where: "title LIKE ? OR (type IN ('savingsCreated', 'savingsIncreased', 'savingsWithdrawal') AND title LIKE ?)",
      whereArgs: ["Savings: ${sav.title}%", "%${sav.title}%"],
    );

    await db.delete('savings_allocations', where: 'savingsId = ?', whereArgs: [id]);
    await db.delete('savings_transactions', where: 'savingsId = ?', whereArgs: [id]);
    await db.delete('savings', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'transactions',
      where: "title LIKE ? OR (type IN ('savingsCreated', 'savingsIncreased', 'savingsWithdrawal') AND title LIKE ?)",
      whereArgs: ["Savings: ${sav.title}%", "%${sav.title}%"],
    );

    if (sav.title.isNotEmpty) {
      await db.insert('sync_queue', {
        'entity_type': 'savings',
        'entity_id': id.toString(),
        'action': 'delete_tab',
        'payload': jsonEncode({'tabName': SyncService.savingsTabName(sav.title)}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });

      for (var tx in txs) {
        final syncId = tx['sync_id']?.toString();
        if (syncId != null && syncId.isNotEmpty) {
          await db.insert('sync_queue', {
            'entity_type': 'transaction',
            'entity_id': syncId,
            'action': 'delete',
            'payload': jsonEncode({'id': syncId}),
            'created_at': DateTime.now().toIso8601String(),
            'retry_count': 0,
            'last_error': null,
          });
        }
      }
    }

    await fetchSavings();
    await fetchSavingsTransactions();
    await fetchTransactions();
    await fetchWallets();
    syncNow();
  }

  Future<List<Wallet>> getWalletsForSavings(int savingsId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> data = await db.query(
      'savings_allocations',
      where: 'savingsId = ? AND amount > 0',
      whereArgs: [savingsId],
    );
    final walletIds = data.map((e) => e['walletId'] as int).toSet();
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
      await db.insert('sync_queue', {
        'entity_type': 'loan',
        'entity_id': id.toString(),
        'action': 'update_category_name',
        'payload': jsonEncode({'oldName': oldName, 'newName': newName}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      syncNow();
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
      await db.insert('sync_queue', {
        'entity_type': 'investment',
        'entity_id': id.toString(),
        'action': 'rename_tab',
        'payload': jsonEncode({
          'oldTabName': SyncService.investmentTabName(oldTitle),
          'newTabName': SyncService.investmentTabName(newTitle),
        }),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      await db.insert('sync_queue', {
        'entity_type': 'investment',
        'entity_id': id.toString(),
        'action': 'update_category_name',
        'payload': jsonEncode({'oldName': oldTitle, 'newName': newTitle}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      syncNow();
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
      await db.insert('sync_queue', {
        'entity_type': 'savings',
        'entity_id': id.toString(),
        'action': 'rename_tab',
        'payload': jsonEncode({
          'oldTabName': SyncService.savingsTabName(oldTitle),
          'newTabName': SyncService.savingsTabName(newTitle),
        }),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      await db.insert('sync_queue', {
        'entity_type': 'savings',
        'entity_id': id.toString(),
        'action': 'update_category_name',
        'payload': jsonEncode({'oldName': oldTitle, 'newName': newTitle}),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      });
      syncNow();
    }
  }

  // --- Financial Summaries (Rules Based) ---
  double get totalWalletAssets {
    // Rule: Wallet Asset = Withdrawable + Frozen
    return _wallets.fold(0, (sum, w) => sum + w.balance + w.frozenAmount);
  }

  double get totalCashBalance {
    return _wallets.fold(0, (sum, w) => sum + w.balance);
  }

  double get totalFrozenBalance {
    return _wallets.fold(0, (sum, w) => sum + w.frozenAmount);
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

  double get totalInvestmentBalance {
    return totalInvestments;
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

  double get totalNetWorth => netWorth;

  double get totalGivenLoans => totalLoanReceivable;

  double get totalTakenLoans => totalLoanPayable;

  double get totalSavingsBalance {
    return _savings.fold(0, (sum, s) => sum + s.amount);
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

  // --- Reset & Sync Logic ---
  Future<void> resetApp() async {
    await SyncService.resetSheet(defaultWalletName: 'Wallet-Main Wallet');
    await DatabaseHelper.instance.resetDatabase();
    await fetchAll();
    _conflicts.clear();
    _syncWarnings.clear();
    notifyListeners();
  }

  // Public sync entry point called by UI buttons and automatic triggers
  Future<void> syncFromSheet() => syncNow(showLoading: true);

  /// Performs a silent check without showing a top-bar loading indicator.
  /// Only starts actual synchronization if pending changes exist or remote data differs.
  Future<void> silentSyncCheck() async {
    if (_isSyncing) return;

    final reachable = await SyncService.isBackendReachable();
    if (!reachable) return;

    final queue = await DatabaseHelper.instance.getSyncQueue();
    if (queue.isNotEmpty) {
      await syncNow(showLoading: true);
      return;
    }

    // Check remote Google Sheets silently
    final fetchResult = await SyncService.fetchFromSheet();
    if (!fetchResult.isSuccess) return;

    if (fetchResult.warnings.isNotEmpty) {
      _syncWarnings.clear();
      _syncWarnings.addAll(fetchResult.warnings);
      notifyListeners();
    }

    final hasChanges = await _checkForRemoteChanges(fetchResult.data);
    if (hasChanges) {
      await _performSyncWithData(fetchResult.data, fetchResult.warnings, showLoading: true);
    }
  }

  Future<bool> _checkForRemoteChanges(List<Map<String, dynamic>> remoteData) async {
    if (remoteData.isEmpty) return false;
    final db = await DatabaseHelper.instance.database;
    final localTxRows = await db.query('transactions');
    final Map<String, Map<String, dynamic>> localMap = {};
    for (var r in localTxRows) {
      final sId = r['sync_id']?.toString() ?? '';
      if (sId.isNotEmpty) localMap[sId] = r;
    }

    for (var remote in remoteData) {
      final rId = remote['id']?.toString().trim() ?? '';
      if (rId.isEmpty) continue;
      final local = localMap[rId];
      if (local == null) {
        return true; // New remote record
      }
      final localStatus = local['sync_status']?.toString() ?? 'synced';
      if (localStatus == 'synced') {
        final diffs = _compareAllSevenFields(
          local, 
          remote, 
          local['walletId'] as int? ?? 0, 
          local['toWalletId'] as int?, 
          _getTypeFromLabel(remote['transectionType']?.toString() ?? ''),
        );
        if (diffs.isNotEmpty) {
          return true; // Existing record updated on Sheet
        }
      }
    }
    return false;
  }

  Future<void> syncNow({bool showLoading = true}) async {
    if (_isSyncing) {
      _syncRequestedAgain = true;
      return;
    }
    if (showLoading) {
      _isSyncing = true;
      _syncStatusMessage = "Syncing...";
      notifyListeners();
    }

    try {
      // Step 1: Push pending queue first so Sheet reflects any deletions/updates before fetching
      await _pushPendingQueue();

      // Step 2: Fetch remote state
      final fetchResult = await SyncService.fetchFromSheet();
      if (!fetchResult.isSuccess) {
        _syncStatusMessage = "Backend unreachable / Offline";
        return;
      }

      // Step 3: Reconcile incoming data
      await _reconcileFromData(fetchResult.data, fetchResult.warnings);

      _lastSyncTime = DateTime.now();
      _syncStatusMessage = _conflicts.isEmpty ? "Synced" : "Synced with conflicts";
    } catch (e) {
      debugPrint("Sync Error: $e");
      _syncStatusMessage = "Offline / Sync Error";
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_syncRequestedAgain) {
        _syncRequestedAgain = false;
        syncNow(showLoading: showLoading);
      }
    }
  }

  Future<void> _performSyncWithData(
    List<Map<String, dynamic>> remoteData,
    List<String> remoteWarnings, {
    bool showLoading = true,
  }) async {
    if (_isSyncing) {
      _syncRequestedAgain = true;
      return;
    }
    if (showLoading) {
      _isSyncing = true;
      _syncStatusMessage = "Syncing...";
      notifyListeners();
    }

    try {
      await _pushPendingQueue();
      await _reconcileFromData(remoteData, remoteWarnings);

      _lastSyncTime = DateTime.now();
      _syncStatusMessage = _conflicts.isEmpty ? "Synced" : "Synced with conflicts";
    } catch (e) {
      debugPrint("Sync Error: $e");
      _syncStatusMessage = "Offline / Sync Error";
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_syncRequestedAgain) {
        _syncRequestedAgain = false;
        syncNow(showLoading: showLoading);
      }
    }
  }

  Future<void> _reconcileFromData(List<Map<String, dynamic>> remoteData, List<String> remoteWarnings) async {
    _syncWarnings.clear();
    _syncWarnings.addAll(remoteWarnings);
    _conflicts.clear();

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // Query pending deletes from sync_queue to avoid resurrecting deleted entities/transactions
      final pendingQueue = await txn.query('sync_queue');
      final Set<String> pendingDeleteIds = {};
      final Set<String> pendingDeleteTabs = {};
      for (var q in pendingQueue) {
        final action = q['action']?.toString();
        if (action == 'delete') {
          final eId = q['entity_id']?.toString() ?? '';
          if (eId.isNotEmpty) pendingDeleteIds.add(eId);
        } else if (action == 'delete_tab') {
          try {
            final payload = jsonDecode(q['payload']?.toString() ?? '{}');
            final tabName = payload['tabName']?.toString();
            if (tabName != null && tabName.isNotEmpty) {
              pendingDeleteTabs.add(tabName.toLowerCase());
              pendingDeleteTabs.add(SyncService.stripTabPrefix(tabName).toLowerCase());
            }
          } catch (_) {}
        }
      }

      final localTxRows = await txn.query('transactions');
      final Map<String, Map<String, dynamic>> localMapBySyncId = {};
      for (var row in localTxRows) {
        final sId = row['sync_id']?.toString() ?? row['id']?.toString() ?? '';
        if (sId.isNotEmpty) {
          localMapBySyncId[sId] = row;
        }
      }

      for (var item in remoteData) {
        final row = Map<String, dynamic>.from(item);
        final remoteId = row['id']?.toString().trim() ?? '';
        if (remoteId.isEmpty) continue;
        if (pendingDeleteIds.contains(remoteId)) {
          // Skip resurrection of transaction pending deletion
          continue;
        }

        final rawAmount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;
        final rawDate = _parseSheetDate(row['date']?.toString());
        final rawNote = row['note']?.toString() ?? '';
        final rawTitleCategory = row['titleCategory']?.toString() ?? 'General';
        final typeLabel = row['transectionType']?.toString() ?? 'Expense';
        final type = _getTypeFromLabel(typeLabel);
        final rawWalletName = row['walletName']?.toString() ?? 'Main Wallet';
        final cleanWalletName = SyncService.stripTabPrefix(rawWalletName);

        final localTx = localMapBySyncId[remoteId];

        // Parse wallet and transfer destination
        int walletId = 0;
        int? toWalletId;
        int? categoryId;

        if (localTx != null) {
          // If transaction already exists locally, preserve existing walletId, toWalletId, and categoryId
          // to prevent entity duplicates when entities are renamed.
          walletId = localTx['walletId'] as int? ?? 0;
          toWalletId = localTx['toWalletId'] as int?;
          categoryId = localTx['categoryId'] as int?;
        } else {
          final entityTitle = _extractName(rawTitleCategory);
          if (pendingDeleteTabs.contains(entityTitle.toLowerCase()) ||
              pendingDeleteTabs.contains(rawTitleCategory.toLowerCase()) ||
              pendingDeleteTabs.contains(cleanWalletName.toLowerCase())) {
            // Belongs to a deleted entity or tab; skip resurrection
            continue;
          }

          if (type == TransactionType.transfer && rawTitleCategory.isNotEmpty) {
            if (rawTitleCategory.contains(' - ')) {
              final parts = rawTitleCategory.split(' - ');
              final sourceName = SyncService.stripTabPrefix(parts[0].trim());
              final targetName = parts.length > 1 ? SyncService.stripTabPrefix(parts[1].trim()) : '';
              walletId = await _getOrCreateWalletIdInTx(txn, sourceName);
              if (targetName.isNotEmpty && targetName.toLowerCase() != sourceName.toLowerCase()) {
                toWalletId = await _getOrCreateWalletIdInTx(txn, targetName);
              }
            } else if (rawTitleCategory.startsWith('To ')) {
              walletId = await _getOrCreateWalletIdInTx(txn, cleanWalletName);
              final targetName = SyncService.stripTabPrefix(rawTitleCategory.substring(3).trim());
              if (targetName.isNotEmpty && targetName.toLowerCase() != cleanWalletName.toLowerCase()) {
                toWalletId = await _getOrCreateWalletIdInTx(txn, targetName);
              }
            } else if (rawTitleCategory.startsWith('From ')) {
              final sourceName = SyncService.stripTabPrefix(rawTitleCategory.substring(5).trim());
              if (sourceName.isNotEmpty && sourceName.toLowerCase() != cleanWalletName.toLowerCase()) {
                walletId = await _getOrCreateWalletIdInTx(txn, sourceName);
              }
              toWalletId = await _getOrCreateWalletIdInTx(txn, cleanWalletName);
            } else {
              walletId = await _getOrCreateWalletIdInTx(txn, cleanWalletName);
            }
          } else {
            if (cleanWalletName != 'N/A' && cleanWalletName != 'Investment Principal' && cleanWalletName != 'None' && cleanWalletName != 'Loans' && cleanWalletName.isNotEmpty) {
              walletId = await _getOrCreateWalletIdInTx(txn, cleanWalletName);
            } else if (_isLoanTx(type) || type == TransactionType.income || type == TransactionType.expense) {
              walletId = await _getDefaultWalletIdInTx(txn);
            }
          }

          // Category & Entity handling for new remote transactions
          if (type == TransactionType.income || type == TransactionType.expense) {
            categoryId = await _getOrCreateCategoryIdInTx(txn, rawTitleCategory, type);
          } else if (rawTitleCategory.isNotEmpty && rawTitleCategory != 'General') {
            final entityTitle = _extractName(rawTitleCategory);
            if (_isInvestmentTx(type)) {
              final exists = (await txn.rawQuery('SELECT * FROM investments WHERE LOWER(title) = LOWER(?)', [entityTitle])).isNotEmpty;
              if (!exists) {
                await txn.insert('investments', {
                  'title': entityTitle,
                  'amount': 0.0,
                  'date': rawDate,
                  'note': 'Synced from Sheet',
                });
              }
            } else if (_isSavingsTx(type)) {
              final exists = (await txn.rawQuery('SELECT * FROM savings WHERE LOWER(title) = LOWER(?)', [entityTitle])).isNotEmpty;
              if (!exists) {
                await txn.insert('savings', {
                  'title': entityTitle,
                  'amount': 0.0,
                  'date': rawDate,
                  'note': 'Synced from Sheet',
                });
              }
            } else if (_isLoanTx(type)) {
              bool isDebt = type == TransactionType.loanTaken || type == TransactionType.loanTakenMore || type == TransactionType.loanRepaid;
              final exists = (await txn.rawQuery('SELECT * FROM loan_recipients WHERE LOWER(name) = LOWER(?) AND isDebt = ?', [entityTitle, isDebt ? 1 : 0])).isNotEmpty;
              if (!exists) {
                await txn.insert('loan_recipients', {
                  'name': entityTitle,
                  'totalAmount': 0.0,
                  'isDebt': isDebt ? 1 : 0,
                });
              }
            }
          }
        }

        if (localTx == null) {
          // 1. Transaction added directly in Google Sheets while app was offline
          await txn.insert('transactions', {
            'sync_id': remoteId,
            'title': rawTitleCategory,
            'amount': rawAmount,
            'date': rawDate,
            'note': rawNote,
            'type': type.name,
            'walletId': walletId,
            'toWalletId': toWalletId,
            'categoryId': categoryId,
            'sync_status': 'synced',
            'updated_at': rawDate,
          });
        } else {
          // 2. Transaction exists on both sides
          final localSyncStatus = localTx['sync_status']?.toString() ?? 'synced';

          if (localSyncStatus == 'synced') {
            // Google Sheets is preferred source of truth for already-synchronized data
            await txn.update(
              'transactions',
              {
                'title': rawTitleCategory,
                'amount': rawAmount,
                'date': rawDate,
                'note': rawNote,
                'type': type.name,
                'walletId': walletId,
                'toWalletId': toWalletId,
                'categoryId': categoryId,
                'sync_status': 'synced',
                'updated_at': rawDate,
              },
              where: 'id = ?',
              whereArgs: [localTx['id']],
            );
          } else {
            // localSyncStatus == 'pending' or 'conflict'
            // Compare all 7 fields!
            final diffs = _compareAllSevenFields(localTx, row, walletId, toWalletId, type);
            if (diffs.isNotEmpty) {
              // Genuine conflict: Record clear warning and block transaction
              final warningMsg = "Conflict on $remoteId: differing in ${diffs.join(', ')}";
              _syncWarnings.add(warningMsg);
              _conflicts.add({
                'sync_id': remoteId,
                'local_id': localTx['id'],
                'differences': diffs,
                'local': localTx,
                'remote': row,
              });

              // Block conflicting transaction in SQLite without modifying original note or data
              await txn.update(
                'transactions',
                {'sync_status': 'conflict'},
                where: 'id = ?',
                whereArgs: [localTx['id']],
              );
            } else {
              // Data is identical: mark synced
              await txn.update(
                'transactions',
                {'sync_status': 'synced'},
                where: 'id = ?',
                whereArgs: [localTx['id']],
              );
            }
          }
        }
      }

      // Finalized Deletion Rule (Section 8):
      // Absence from Sheet is not reliable proof of deletion; retain local records!

      // Recalculate wallet balances within the atomic transaction
      await _recalculateWalletBalancesInTx(txn);
    });

    await fetchAll();
  }

  List<String> _compareAllSevenFields(
    Map<String, dynamic> localTx,
    Map<String, dynamic> remoteRow,
    int resolvedRemoteWalletId,
    int? resolvedRemoteToWalletId,
    TransactionType resolvedRemoteType,
  ) {
    final localWalletId = localTx['walletId'] as int?;
    String localWName = '';
    if (localWalletId != null && localWalletId != 0 && _wallets.isNotEmpty) {
      localWName = _wallets.firstWhere((w) => w.id == localWalletId, orElse: () => _wallets.first).name;
    }
    return compareSevenFields(
      localTx: localTx,
      remoteRow: remoteRow,
      resolvedRemoteWalletId: resolvedRemoteWalletId,
      resolvedRemoteType: resolvedRemoteType,
      localWalletName: localWName,
    );
  }

  @visibleForTesting
  static List<String> compareSevenFields({
    required Map<String, dynamic> localTx,
    required Map<String, dynamic> remoteRow,
    required int resolvedRemoteWalletId,
    required TransactionType resolvedRemoteType,
    required String localWalletName,
  }) {
    final List<String> diffs = [];

    // 1. Transaction ID: remoteRow['id'] == localTx['sync_id'] (already matched)

    // 2. Date comparison (normalized by calendar day)
    final localDateStr = localTx['date']?.toString().split('T').first ?? '';
    final remoteDateParsed = parseSheetDate(remoteRow['date']?.toString()).split('T').first;
    if (localDateStr != remoteDateParsed) {
      diffs.add('Date (Local: $localDateStr, Sheet: $remoteDateParsed)');
    }

    // 3. Title/Category comparison (normalized)
    final localTitle = (localTx['title']?.toString() ?? '').trim().toLowerCase();
    final remoteTitle = (remoteRow['titleCategory']?.toString() ?? '').trim().toLowerCase();
    if (localTitle != remoteTitle) {
      diffs.add('Title/Category (Local: "${localTx['title']}", Sheet: "${remoteRow['titleCategory']}")');
    }

    // 4. Transaction Type comparison
    final localType = localTx['type']?.toString().toLowerCase() ?? '';
    final remoteType = resolvedRemoteType.name.toLowerCase();
    if (localType != remoteType) {
      diffs.add('Type (Local: "$localType", Sheet: "$remoteType")');
    }

    // 5. Amount comparison (tolerance 0.01)
    final localAmount = (localTx['amount'] as num).toDouble();
    final remoteAmount = double.tryParse(remoteRow['amount']?.toString() ?? '0') ?? 0.0;
    if ((localAmount - remoteAmount).abs() > 0.01) {
      diffs.add('Amount (Local: $localAmount, Sheet: $remoteAmount)');
    }

    // 6. Note comparison (trimmed)
    final localNote = (localTx['note']?.toString() ?? '').trim();
    final remoteNote = (remoteRow['note']?.toString() ?? '').trim();
    if (localNote != remoteNote) {
      diffs.add('Note (Local: "$localNote", Sheet: "$remoteNote")');
    }

    // 7. Wallet Name comparison
    if (resolvedRemoteWalletId != 0 && localWalletName.isNotEmpty) {
      final remoteWName = remoteRow['walletName']?.toString() ?? '';
      if (localWalletName.trim().toLowerCase() != remoteWName.trim().toLowerCase()) {
        diffs.add('Wallet (Local: "$localWalletName", Sheet: "$remoteWName")');
      }
    }

    return diffs;
  }

  Future<void> _pushPendingQueue() async {
    final queueItems = await DatabaseHelper.instance.getSyncQueue();
    if (queueItems.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    final txRows = await db.query('transactions');
    final Map<String, String> statusBySyncId = {
      for (var tx in txRows)
        if (tx['sync_id'] != null) tx['sync_id'].toString(): tx['sync_status']?.toString() ?? 'synced'
    };

    // Filter queue items: Skip any transactions blocked due to conflict
    final List<Map<String, dynamic>> eligibleQueueItems = [];
    for (var item in queueItems) {
      final entityType = item['entity_type'] as String;
      final entityId = item['entity_id'] as String;

      if (entityType == 'transaction' && statusBySyncId[entityId] == 'conflict') {
        // Blocked from automatic push until conflict resolved!
        continue;
      }
      eligibleQueueItems.add(item);
    }

    if (eligibleQueueItems.isEmpty) return;

    final List<Map<String, dynamic>> batchOps = [];
    for (var item in eligibleQueueItems) {
      try {
        final payload = jsonDecode(item['payload'] as String);
        batchOps.add({
          "action": item['action'],
          "payload": payload,
        });
      } catch (_) {}
    }

    Set<String> successfullyProcessedIds = {};
    if (batchOps.isNotEmpty) {
      final batchResult = await SyncService.batchSync(batchOps);
      final List<dynamic> processed = batchResult['processedIds'] ?? [];
      successfullyProcessedIds = processed.map((e) => e.toString()).toSet();

      for (var item in eligibleQueueItems) {
        final itemId = item['id'] as int;
        final entityId = item['entity_id'] as String;
        final action = item['action'] as String;

        if (successfullyProcessedIds.contains(entityId)) {
          await DatabaseHelper.instance.deleteSyncQueueItem(itemId);
          if (action != 'delete') {
            await db.update('transactions', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [entityId]);
          }
        }
      }
    }

    // For any items not processed by batch, process remaining eligible items individually
    final remainingQueue = await DatabaseHelper.instance.getSyncQueue();
    for (var item in remainingQueue) {
      final itemId = item['id'] as int;
      final entityType = item['entity_type'] as String;
      final entityId = item['entity_id'] as String;
      final action = item['action'] as String;

      if (entityType == 'transaction' && statusBySyncId[entityId] == 'conflict') {
        continue;
      }

      bool itemSuccess = false;
      try {
        final payload = jsonDecode(item['payload'] as String);

        if (entityType == 'transaction') {
          if (action == 'delete') {
            itemSuccess = await SyncService.deleteTransaction(entityId);
          } else {
            itemSuccess = await SyncService.syncTransaction(
              TransactionModel(
                syncId: payload['id']?.toString(),
                title: payload['titleCategory']?.toString() ?? '',
                amount: double.tryParse(payload['amount']?.toString() ?? '0') ?? 0.0,
                date: _parseSheetDateToDateTime(payload['date']?.toString()),
                note: payload['note']?.toString() ?? '',
                type: _getTypeFromLabel(payload['transectionType']?.toString() ?? 'Expense'),
                walletId: 0,
              ),
              payload['walletName']?.toString() ?? 'Main Wallet',
              payload['titleCategory']?.toString() ?? '',
              payload['transectionType']?.toString() ?? 'Expense',
              secondaryTabName: payload['secondaryTabName']?.toString(),
              action: 'create',
            );
          }
        } else if (action == 'create_tab') {
          itemSuccess = await SyncService.createTab(payload['tabName']?.toString() ?? '');
        } else if (action == 'delete_tab') {
          itemSuccess = await SyncService.deleteTab(payload['tabName']?.toString() ?? '');
        } else if (action == 'rename_tab') {
          itemSuccess = await SyncService.renameTab(payload['oldTabName']?.toString() ?? '', payload['newTabName']?.toString() ?? '');
        } else if (action == 'update_wallet_name') {
          itemSuccess = await SyncService.updateWalletName(payload['oldName']?.toString() ?? '', payload['newName']?.toString() ?? '');
        } else if (action == 'update_category_name') {
          itemSuccess = await SyncService.updateCategoryName(payload['oldName']?.toString() ?? '', payload['newName']?.toString() ?? '');
        } else if (action == 'clear_category_name') {
          itemSuccess = await SyncService.clearCategoryName(payload['categoryName']?.toString() ?? '');
        }

        if (itemSuccess) {
          await DatabaseHelper.instance.deleteSyncQueueItem(itemId);
          if (entityType == 'transaction' && action != 'delete') {
            await db.update('transactions', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [entityId]);
          }
        } else {
          await DatabaseHelper.instance.updateSyncQueueRetry(itemId, 'Individual sync failed');
        }
      } catch (err) {
        await DatabaseHelper.instance.updateSyncQueueRetry(itemId, err.toString());
      }
    }
  }

  Future<TransactionModel> _insertTransactionInTx(Transaction txn, TransactionModel tx) async {
    final int id = await txn.insert('transactions', tx.toMap());
    final String formattedSyncId = TransactionModel.formatSyncId(id);
    await txn.update('transactions', {'sync_id': formattedSyncId}, where: 'id = ?', whereArgs: [id]);
    final insertedTx = tx.copyWith(id: id, syncId: formattedSyncId);
    await _enqueueTxSyncInTx(txn, insertedTx, 'create');
    return insertedTx;
  }

  Future<void> _enqueueTxSyncInTx(Transaction txn, TransactionModel tx, String action) async {
    final payload = _buildTxSyncPayload(tx);
    await txn.insert('sync_queue', {
      'entity_type': 'transaction',
      'entity_id': tx.syncId,
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'last_error': null,
    });
  }

  Map<String, dynamic> _buildTxSyncPayload(TransactionModel tx) {
    if (tx.type == TransactionType.transfer && tx.toWalletId != null) {
      final fromWallet = _wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => _wallets.first);
      final toWallet = _wallets.firstWhere((w) => w.id == tx.toWalletId, orElse: () => _wallets.first);
      return {
        "id": tx.syncId,
        "date": "${tx.date.day.toString().padLeft(2, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.year.toString().substring(2)}",
        "titleCategory": "${fromWallet.name} - ${toWallet.name}",
        "transectionType": _getTransectionTypeLabel(tx.type),
        "amount": tx.amount,
        "note": tx.note,
        "walletName": fromWallet.name,
        "secondaryTabName": toWallet.name,
      };
    } else {
      String walletName = "N/A";
      if (tx.walletId != 0 && _wallets.isNotEmpty) {
        final wallet = _wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => _wallets.first);
        walletName = wallet.name;
      }

      String titleCategory = "";
      String? secondaryTabName;

      if (tx.categoryId != null && _categories.isNotEmpty) {
        titleCategory = _categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => Category(name: 'General', iconCode: 0, type: CategoryType.expense),
        ).name;
      } else {
        titleCategory = _extractName(tx.title);
        if (_isInvestmentTx(tx.type)) {
          secondaryTabName = titleCategory;
          if (tx.walletId == 0) walletName = "N/A";
        } else if (_isSavingsTx(tx.type)) {
          secondaryTabName = titleCategory;
        } else if (_isLoanTx(tx.type)) {
          secondaryTabName = "Loans";
        }
      }

      return {
        "id": tx.syncId,
        "date": "${tx.date.day.toString().padLeft(2, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.year.toString().substring(2)}",
        "titleCategory": titleCategory,
        "transectionType": _getTransectionTypeLabel(tx.type),
        "amount": tx.amount,
        "note": tx.note,
        "walletName": walletName,
        ...? (secondaryTabName != null ? {"secondaryTabName": secondaryTabName} : null),
      };
    }
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
    final trimmed = name.trim();
    if (trimmed.isEmpty) return await _getDefaultWalletIdInTx(txn);
    final List<Map<String, dynamic>> res = await txn.rawQuery(
      'SELECT * FROM wallets WHERE LOWER(name) = LOWER(?)', [trimmed]
    );
    if (res.isNotEmpty) return res.first['id'] as int;
    return await txn.insert('wallets', {
      'name': trimmed,
      'balance': 0.0,
      'frozen_amount': 0.0,
      'color': 0xFF2196F3,
      'isDefault': 0,
      'is_archived': 0
    });
  }

  Future<int> _getDefaultWalletIdInTx(Transaction txn) async {
    final res = await txn.query('wallets', where: 'isDefault = 1', limit: 1);
    if (res.isNotEmpty) return res.first['id'] as int;
    final all = await txn.query('wallets', limit: 1);
    if (all.isNotEmpty) return all.first['id'] as int;
    return await txn.insert('wallets', {
      'name': 'Main Wallet',
      'balance': 0.0,
      'frozen_amount': 0.0,
      'color': 0xFF7F3DFF,
      'isDefault': 1,
      'is_archived': 0,
    });
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
    String t = fullTitle.trim();
    if (t.contains(': ')) return t.split(': ').last.trim();
    if (t.contains(' · ')) return t.split(' · ').last.trim();
    if (t.contains('·')) return t.split('·').last.trim();
    return t;
  }

  String _parseSheetDate(String? raw) => parseSheetDate(raw);

  static String parseSheetDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now().toIso8601String();
    try {
      String s = raw.trim();
      
      // If it contains 'T', extract calendar date before 'T' to preserve calendar day across timezones
      if (s.contains('T')) {
        final datePart = s.split('T').first.trim();
        final parts = datePart.split('-');
        if (parts.length == 3 && parts[0].length == 4) {
          int year = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int day = int.parse(parts[2].replaceAll(RegExp(r'\D'), ''));
          return DateTime(year, month, day, 12, 0, 0).toIso8601String();
        }
      }

      if (s.contains('-') || s.contains('/')) {
        final separator = s.contains('-') ? '-' : '/';
        final parts = s.split(separator);
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            int year = int.parse(parts[0]);
            int month = int.parse(parts[1]);
            int day = int.parse(parts[2].replaceAll(RegExp(r'\D'), ''));
            return DateTime(year, month, day, 12, 0, 0).toIso8601String();
          } else {
            int p0 = int.parse(parts[0].replaceAll(RegExp(r'\D'), ''));
            int p1 = int.parse(parts[1].replaceAll(RegExp(r'\D'), ''));
            int year = int.parse(parts[2].replaceAll(RegExp(r'\D'), ''));
            if (year < 100) year += 2000;

            int day, month;
            if (p1 > 12) {
              month = p0;
              day = p1;
            } else {
              day = p0;
              month = p1;
            }
            return DateTime(year, month, day, 12, 0, 0).toIso8601String();
          }
        }
      }
      final parsed = DateTime.parse(s);
      return DateTime(parsed.year, parsed.month, parsed.day, 12, 0, 0).toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  DateTime _parseSheetDateToDateTime(String? raw) {
    return DateTime.parse(_parseSheetDate(raw));
  }
}
