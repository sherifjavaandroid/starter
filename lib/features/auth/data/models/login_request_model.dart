class LoginRequestModel {
  final String email;
  final String password;
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;
  final String? deviceOS;
  final String? deviceOSVersion;
  final String? appVersion;
  final String? fcmToken;

  LoginRequestModel({
    required this.email,
    required this.password,
    this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.deviceOS,
    this.deviceOSVersion,
    this.appVersion,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'device_os': deviceOS,
      'device_os_version': deviceOSVersion,
      'app_version': appVersion,
      'fcm_token': fcmToken,
    };
  }

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) {
    return LoginRequestModel(
      email: json['email'] as String,
      password: json['password'] as String,
      deviceId: json['device_id'] as String?,
      deviceName: json['device_name'] as String?,
      deviceModel: json['device_model'] as String?,
      deviceOS: json['device_os'] as String?,
      deviceOSVersion: json['device_os_version'] as String?,
      appVersion: json['app_version'] as String?,
      fcmToken: json['fcm_token'] as String?,
    );
  }

  LoginRequestModel copyWith({
    String? email,
    String? password,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? deviceOS,
    String? deviceOSVersion,
    String? appVersion,
    String? fcmToken,
  }) {
    return LoginRequestModel(
      email: email ?? this.email,
      password: password ?? this.password,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceOS: deviceOS ?? this.deviceOS,
      deviceOSVersion: deviceOSVersion ?? this.deviceOSVersion,
      appVersion: appVersion ?? this.appVersion,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}

class SignupRequestModel {
  final String email;
  final String password;
  final String name;
  final String? phoneNumber;
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;
  final String? deviceOS;
  final String? deviceOSVersion;
  final String? appVersion;
  final String? fcmToken;

  SignupRequestModel({
    required this.email,
    required this.password,
    required this.name,
    this.phoneNumber,
    this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.deviceOS,
    this.deviceOSVersion,
    this.appVersion,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'phone_number': phoneNumber,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'device_os': deviceOS,
      'device_os_version': deviceOSVersion,
      'app_version': appVersion,
      'fcm_token': fcmToken,
    };
  }

  factory SignupRequestModel.fromJson(Map<String, dynamic> json) {
    return SignupRequestModel(
      email: json['email'] as String,
      password: json['password'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String?,
      deviceId: json['device_id'] as String?,
      deviceName: json['device_name'] as String?,
      deviceModel: json['device_model'] as String?,
      deviceOS: json['device_os'] as String?,
      deviceOSVersion: json['device_os_version'] as String?,
      appVersion: json['app_version'] as String?,
      fcmToken: json['fcm_token'] as String?,
    );
  }
}

class RefreshTokenRequestModel {
  final String refreshToken;
  final String? deviceId;

  RefreshTokenRequestModel({
    required this.refreshToken,
    this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'refresh_token': refreshToken,
      'device_id': deviceId,
    };
  }
}

class PasswordResetRequestModel {
  final String email;

  PasswordResetRequestModel({required this.email});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}

class ChangePasswordRequestModel {
  final String currentPassword;
  final String newPassword;

  ChangePasswordRequestModel({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'current_password': currentPassword,
      'new_password': newPassword,
    };
  }
}