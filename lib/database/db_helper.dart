import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE loan_recipients ADD COLUMN isDebt INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE investments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE investment_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          investmentId INTEGER NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          walletId INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (investmentId) REFERENCES investments (id),
          FOREIGN KEY (walletId) REFERENCES wallets (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE savings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE savings_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          savingsId INTEGER NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          walletId INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (savingsId) REFERENCES savings (id),
          FOREIGN KEY (walletId) REFERENCES wallets (id)
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add title to transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN title TEXT DEFAULT ""');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE wallets ADD COLUMN frozen_amount REAL DEFAULT 0.0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE wallets ADD COLUMN is_archived INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE categories ADD COLUMN is_archived INTEGER DEFAULT 0');
      // Table for wallet-level savings allocation to track frozen amounts per goal per wallet
      await db.execute('''
        CREATE TABLE savings_allocations (
          savingsId INTEGER NOT NULL,
          walletId INTEGER NOT NULL,
          amount REAL DEFAULT 0.0,
          PRIMARY KEY (savingsId, walletId),
          FOREIGN KEY (savingsId) REFERENCES savings (id),
          FOREIGN KEY (walletId) REFERENCES wallets (id)
        )
      ''');
    }
    if (oldVersion < 7) {
      // Version 7: Offline sync queue and tracking columns
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN sync_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN sync_status TEXT DEFAULT "synced"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT');
      } catch (_) {}

      await db.execute('UPDATE transactions SET sync_id = CAST(id AS TEXT) WHERE sync_id IS NULL OR sync_id = ""');
      await db.execute('UPDATE transactions SET updated_at = date WHERE updated_at IS NULL');
      await db.execute('UPDATE transactions SET sync_status = "synced" WHERE sync_status IS NULL OR sync_status = ""');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          action TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          last_error TEXT
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    // Wallets Table
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        frozen_amount REAL DEFAULT 0.0,
        color INTEGER NOT NULL,
        isDefault INTEGER NOT NULL,
        is_archived INTEGER DEFAULT 0
      )
    ''');

    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        type TEXT NOT NULL,
        is_archived INTEGER DEFAULT 0
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        type TEXT NOT NULL,
        walletId INTEGER NOT NULL,
        toWalletId INTEGER,
        categoryId INTEGER,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT,
        FOREIGN KEY (walletId) REFERENCES wallets (id),
        FOREIGN KEY (toWalletId) REFERENCES wallets (id),
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    // Loan Recipients Table
    await db.execute('''
      CREATE TABLE loan_recipients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        isDebt INTEGER DEFAULT 0
      )
    ''');

    // Loan Transactions Table
    await db.execute('''
      CREATE TABLE loan_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipientId INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        walletId INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (recipientId) REFERENCES loan_recipients (id),
        FOREIGN KEY (walletId) REFERENCES wallets (id)
      )
    ''');

    // Investments Table
    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');

    // Investment Transactions Table
    await db.execute('''
      CREATE TABLE investment_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        investmentId INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        walletId INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (investmentId) REFERENCES investments (id),
        FOREIGN KEY (walletId) REFERENCES wallets (id)
      )
    ''');

    // Savings Table
    await db.execute('''
      CREATE TABLE savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');

    // Savings Transactions Table
    await db.execute('''
      CREATE TABLE savings_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        savingsId INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        walletId INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (savingsId) REFERENCES savings (id),
        FOREIGN KEY (walletId) REFERENCES wallets (id)
      )
    ''');

    // Savings Allocations Table
    await db.execute('''
      CREATE TABLE savings_allocations (
        savingsId INTEGER NOT NULL,
        walletId INTEGER NOT NULL,
        amount REAL DEFAULT 0.0,
        PRIMARY KEY (savingsId, walletId),
        FOREIGN KEY (savingsId) REFERENCES savings (id),
        FOREIGN KEY (walletId) REFERENCES wallets (id)
      )
    ''');

    // Sync Queue Table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Insert Default Wallet
    await db.insert('wallets', {
      'name': 'Main Wallet',
      'balance': 0.0,
      'color': 0xFF7F3DFF,
      'isDefault': 1,
    });

    // Insert Default Categories
    final List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Salary', 'iconCode': 0xe1af, 'type': 'income'},
      {'name': 'Food', 'iconCode': 0xe25a, 'type': 'expense'},
      {'name': 'Transport', 'iconCode': 0xe1d1, 'type': 'expense'},
      {'name': 'Shopping', 'iconCode': 0xe59c, 'type': 'expense'},
    ];
    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await instance.database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> delete(String table, int id) async {
    final db = await instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateWalletBalance(int walletId, double amount) async {
    final db = await instance.database;
    await db.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      [amount, walletId],
    );
  }

  Future<void> updateWalletFrozenBalance(int walletId, double balanceChange, double frozenChange) async {
    final db = await instance.database;
    await db.execute(
      'UPDATE wallets SET balance = balance + ?, frozen_amount = frozen_amount + ? WHERE id = ?',
      [balanceChange, frozenChange, walletId],
    );
  }

  // Sync Queue Helpers
  Future<int> insertSyncQueue(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('sync_queue', row);
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  Future<int> deleteSyncQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncQueueRetry(int id, String error) async {
    final db = await instance.database;
    await db.execute(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<void> clearSyncQueue() async {
    final db = await instance.database;
    await db.delete('sync_queue');
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.delete('wallets');
    await db.delete('categories');
    await db.delete('transactions');
    await db.delete('loan_recipients');
    await db.delete('loan_transactions');
    await db.delete('investments');
    await db.delete('investment_transactions');
    await db.delete('savings');
    await db.delete('savings_transactions');
    await db.delete('savings_allocations');
    await db.delete('sync_queue');

    // Insert Default Wallet
    await db.insert('wallets', {
      'name': 'Main Wallet',
      'balance': 0.0,
      'color': 0xFF7F3DFF,
      'isDefault': 1,
    });

    // Insert Default Categories
    final List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Salary', 'iconCode': 0xe1af, 'type': 'income'},
      {'name': 'Food', 'iconCode': 0xe25a, 'type': 'expense'},
      {'name': 'Transport', 'iconCode': 0xe1d1, 'type': 'expense'},
      {'name': 'Shopping', 'iconCode': 0xe59c, 'type': 'expense'},
    ];
    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }
}
