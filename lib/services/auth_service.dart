import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'drive_resource_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Web Application Client ID from Google Cloud Console for backend OAuth token exchange
  static const String webClientId = '974824598767-c6kjtpehg38o95jkme3b772atk2cn1o7.apps.googleusercontent.com';

  // Initial sign-in uses standard profile scopes to prevent Android ApiException: 10 (DEVELOPER_ERROR).
  // Drive and Sheets scopes are requested incrementally when accessing cloud storage.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOfflineAtLaunch = false;

  String? _customFirstName;
  String? _customLastName;
  String? _customPhotoUrl;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOfflineAtLaunch => _isOfflineAtLaunch;

  @visibleForTesting
  set isOfflineAtLaunchForTesting(bool value) {
    _isOfflineAtLaunch = value;
    notifyListeners();
  }

  @visibleForTesting
  set isInitializingForTesting(bool value) {
    _isInitializing = value;
    notifyListeners();
  }

  String? get customFirstName => _customFirstName;
  String? get customLastName => _customLastName;
  String? get customPhotoUrl => _customPhotoUrl;

  String get firstName {
    if (_customFirstName != null && _customFirstName!.trim().isNotEmpty) {
      return _customFirstName!.trim();
    }
    final gName = _currentUser?.displayName?.trim() ?? '';
    if (gName.isNotEmpty) {
      return gName.split(' ').first;
    }
    return 'User';
  }

  String get lastName {
    if (_customLastName != null && _customLastName!.trim().isNotEmpty) {
      return _customLastName!.trim();
    }
    final gName = _currentUser?.displayName?.trim() ?? '';
    if (gName.isNotEmpty) {
      final parts = gName.split(' ');
      if (parts.length > 1) {
        return parts.sublist(1).join(' ');
      }
    }
    return '';
  }

  String get displayName {
    final first = firstName;
    final last = lastName;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  String? get photoUrl => _customPhotoUrl ?? _currentUser?.photoUrl;

  ImageProvider? get avatarImageProvider {
    final url = photoUrl;
    if (url == null || url.trim().isEmpty) return null;
    final path = url.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  StreamSubscription<GoogleSignInAccount?>? _authSubscription;

  Future<bool> _checkInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1500));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Initializes authentication state and attempts silent sign-in on app launch
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    await _loadCustomProfile();

    final bool hasInternet = await _checkInternetConnection();
    _isOfflineAtLaunch = !hasInternet;

    _authSubscription?.cancel();
    _authSubscription = _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      if (account != null) {
        DriveResourceService.instance.getOrCreateResources().catchError((e) {
          debugPrint("Drive init error on auth change: $e");
          return const DriveResourceResult(isSuccess: false);
        });
      }
      notifyListeners();
    });

    if (!hasInternet) {
      // When opening app without internet, bypass sign-in and allow direct homepage access
      try {
        _currentUser = await _googleSignIn.signInSilently();
      } catch (e) {
        debugPrint("Silent sign-in check offline completed: $e");
      } finally {
        _isInitializing = false;
        notifyListeners();
      }
      return;
    }

    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        DriveResourceService.instance.getOrCreateResources().catchError((e) {
          debugPrint("Drive init error on silent sign-in: $e");
          return const DriveResourceResult(isSuccess: false);
        });
      }
    } catch (e) {
      debugPrint("Silent sign-in check completed: $e");
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadCustomProfile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_prefs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _customFirstName = data['first_name'] as String?;
        _customLastName = data['last_name'] as String?;
        _customPhotoUrl = data['photo_url'] as String?;
      }
    } catch (e) {
      debugPrint("Error loading profile prefs: $e");
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? photoUrl,
  }) async {
    _customFirstName = firstName.trim();
    _customLastName = lastName.trim();
    _customPhotoUrl = photoUrl?.trim();
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_prefs.json');
      await file.writeAsString(jsonEncode({
        'first_name': _customFirstName,
        'last_name': _customLastName,
        'photo_url': _customPhotoUrl,
      }));
    } catch (e) {
      debugPrint("Error saving profile prefs: $e");
    }
  }

  /// Interactive Google Sign-In
  Future<bool> signIn() async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account == null) {
        _errorMessage = "Sign-in cancelled by user";
        return false;
      }

      // Automatically find or create Financedatabase folder & Financedatasheet spreadsheet
      unawaited(DriveResourceService.instance.getOrCreateResources().catchError((e) {
        debugPrint("Error initializing drive resources: $e");
        return const DriveResourceResult(isSuccess: false);
      }));

      return true;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      _errorMessage = "Sign-in failed: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs out the current user session
  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _isOfflineAtLaunch = false;
      DriveResourceService.instance.clearCache();
    } catch (e) {
      debugPrint("Sign-out error: $e");
      _errorMessage = "Sign-out failed: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Disconnects account completely (revokes OAuth consent/tokens)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
      _isOfflineAtLaunch = false;
      DriveResourceService.instance.clearCache();
      notifyListeners();
    } catch (e) {
      debugPrint("Disconnect error: $e");
    }
  }

  /// Request additional OAuth scopes (e.g. for Drive & Sheets)
  Future<bool> requestAdditionalScopes(List<String> scopes) async {
    try {
      return await _googleSignIn.requestScopes(scopes);
    } catch (e) {
      debugPrint("Request scopes error: $e");
      return false;
    }
  }

  /// Verifies if the current session already possesses the requested scopes
  Future<bool> hasScopes(List<String> scopes) async {
    try {
      return await _googleSignIn.canAccessScopes(scopes);
    } catch (e) {
      return false;
    }
  }

  /// Obtains current auth headers (Bearer access token) for Google API requests
  Future<Map<String, String>?> getAuthHeaders() async {
    if (_currentUser == null) return null;
    try {
      return await _currentUser!.authHeaders;
    } catch (e) {
      debugPrint("Error retrieving auth headers: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
