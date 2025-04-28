import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/session_manager.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import '../../domain/usecases/biometric_auth_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final SignupUseCase _signUpUseCase;
  final LogoutUseCase _logoutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final BiometricAuthUseCase _biometricAuthUseCase;
  final SessionManager _sessionManager;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required SignupUseCase signUpUseCase,
    required LogoutUseCase logoutUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    required BiometricAuthUseCase biometricAuthUseCase,
    required SessionManager sessionManager,
  })  : _loginUseCase = loginUseCase,
        _signUpUseCase = signUpUseCase,
        _logoutUseCase = logoutUseCase,
        _refreshTokenUseCase = refreshTokenUseCase,
        _biometricAuthUseCase = biometricAuthUseCase,
        _sessionManager = sessionManager,
        super(AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<SignUpEvent>(_onSignUp);
    on<LogoutEvent>(_onLogout);
    on<RefreshTokenEvent>(_onRefreshToken);
    on<BiometricAuthEvent>(_onBiometricAuth);
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<EnableBiometricAuthEvent>(_onEnableBiometricAuth);
    on<DisableBiometricAuthEvent>(_onDisableBiometricAuth);
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final result = await _loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );

    result.fold(
          (failure) => emit(AuthError(failure.message)),
          (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignUp(SignUpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final result = await _signUpUseCase(
      SignUpParams(
        email: event.email,
        password: event.password,
        name: event.name,
      ),
    );

    result.fold(
          (failure) => emit(AuthError(failure.message)),
          (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final result = await _logoutUseCase(NoParams());

    result.fold(
          (failure) => emit(AuthError(failure.message)),
          (_) => emit(Unauthenticated()),
    );
  }

  Future<void> _onRefreshToken(RefreshTokenEvent event, Emitter<AuthState> emit) async {
    final result = await _refreshTokenUseCase(NoParams());

    result.fold(
          (failure) {
        // If refresh token fails, log out the user
        emit(Unauthenticated());
      },
          (token) {
        // Token refreshed successfully, maintain current state
      },
    );
  }

  Future<void> _onBiometricAuth(BiometricAuthEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final result = await _biometricAuthUseCase(NoParams());

    result.fold(
          (failure) => emit(AuthError(failure.message)),
          (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    // Check if user is logged in and session is valid
    final isSessionValid = await _sessionManager.isSessionValid();

    if (isSessionValid) {
      // Try to get current user
      final result = await _loginUseCase.getCurrentUser();

      result.fold(
            (failure) => emit(Unauthenticated()),
            (user) => emit(Authenticated(user)),
      );
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onEnableBiometricAuth(EnableBiometricAuthEvent event, Emitter<AuthState> emit) async {
    final result = await _biometricAuthUseCase.enableBiometricAuth();

    result.fold(
          (failure) => emit(AuthError(failure.message)),
          (_) {
        if (state is Authenticated) {
          emit((state as Authenticated).copyWith(isBiometricEnabled: true));
        }
      },
    );
  }

  Future<void> _onDisableBiometricAuth(DisableBiometricAuthEvent event, Emitter<AuthState> emit) async {
    final result = await _biometricAuthUseCase.disableBiometricAuth();

    result.fold(
          (failure) => emit(AuthError(failure.message)),
          (_) {
        if (state is Authenticated) {
          emit((state as Authenticated).copyWith(isBiometricEnabled: false));
        }
      },
    );
  }

  // Helper method to check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    final result = await _biometricAuthUseCase.isBiometricEnabled();
    return result.fold(
          (failure) => false,
          (isEnabled) => isEnabled,
    );
  }
}