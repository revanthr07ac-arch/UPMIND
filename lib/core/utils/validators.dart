class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
  );

  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]+$');

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (trimmed.length > 30) {
      return 'Username cannot exceed 30 characters';
    }
    if (!_usernameRegExp.hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Full name is too short';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static final RegExp _otpRegExp = RegExp(r'^\d{6}$');

  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    final trimmed = value.trim();
    if (trimmed.length != 6 || !_otpRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid 6-digit code';
    }
    return null;
  }

  static String maskEmail(String email) {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) return trimmed;
    final parts = trimmed.split('@');
    final name = parts[0];
    final domain = parts.length > 1 ? parts[1] : '';
    if (name.length <= 2) {
      return '${name.isNotEmpty ? name[0] : '*'}*@$domain';
    } else if (name.length <= 4) {
      return '${name[0]}**${name[name.length - 1]}@$domain';
    } else {
      final prefix = name.substring(0, 2);
      final suffix = name.substring(name.length - 1);
      return '$prefix***$suffix@$domain';
    }
  }
}
