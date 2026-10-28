import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  StreamSubscription<GoogleSignInAccount?>? _authSubscription;

  /// Initializes authentication state and attempts silent sign-in on app launch
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

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
