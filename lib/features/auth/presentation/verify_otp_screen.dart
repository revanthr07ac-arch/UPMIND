import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/upmind_logo.dart';
import '../data/auth_repository.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final int initialCooldownSeconds;
  final bool autoStartCooldown;
  final bool autofocus;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.initialCooldownSeconds = 60,
    this.autoStartCooldown = true,
    this.autofocus = true,
  });

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes;

  Timer? _cooldownTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isResending = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (i) {
      final node = FocusNode();
      node.onKeyEvent = (focusNode, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          _focusNodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
      return node;
    });

    _secondsRemaining = widget.initialCooldownSeconds;
    _canResend = widget.initialCooldownSeconds <= 0;
    if (widget.autoStartCooldown && widget.initialCooldownSeconds > 0) {
      _startCooldown();
    }
  }

  @override
  void didUpdateWidget(covariant VerifyOtpScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCooldownSeconds != widget.initialCooldownSeconds) {
      _secondsRemaining = widget.initialCooldownSeconds;
      _canResend = widget.initialCooldownSeconds <= 0;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown([int? seconds]) {
    _cooldownTimer?.cancel();
    final total = seconds ?? widget.initialCooldownSeconds;
    setState(() {
      _secondsRemaining = total;
      _canResend = false;
    });

    if (total <= 0) {
      setState(() {
        _secondsRemaining = 0;
        _canResend = true;
      });
      return;
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        timer.cancel();
        _cooldownTimer = null;
        if (mounted) {
          setState(() {
            _secondsRemaining = 0;
            _canResend = true;
          });
        }
      }
    });
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() {
      _localError = null;
    });

    // Handle full 6-digit paste
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6; i++) {
          if (i < digits.length) {
            _controllers[i].text = digits[i];
          }
        }
        final targetIndex = (digits.length < 6) ? digits.length : 5;
        _focusNodes[targetIndex].requestFocus();
        if (digits.length == 6) {
          _handleVerify();
        }
        return;
      }
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentOtp.length == 6) {
          _handleVerify();
        }
      }
    }
  }

  Future<void> _handleVerify() async {
    final otp = _currentOtp.trim();
    final validationError = Validators.validateOtp(otp);
    if (validationError != null) {
      setState(() {
        _localError = validationError;
      });
      return;
    }

    final success = await ref
        .read(authNotifierProvider.notifier)
        .verifyOtp(email: widget.email.trim(), token: otp);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully! Welcome to UPMIND.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/feed');
    } else if (mounted) {
      final error = ref.read(authNotifierProvider).errorMessage ??
          'Invalid or expired verification code. Please check and try again.';
      setState(() {
        _localError = error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _localError = null;
    });

    final success = await ref
        .read(authNotifierProvider.notifier)
        .resendOtp(email: widget.email.trim());

    if (mounted) {
      setState(() {
        _isResending = false;
      });

      if (success) {
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new 6-digit verification code has been sent to your email.'),
            backgroundColor: AppColors.primaryBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(authNotifierProvider).errorMessage ??
            'Failed to resend code. Please try again.';
        setState(() {
          _localError = error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final maskedEmail = Validators.maskEmail(widget.email);
    final displayedError = _localError ?? authState.errorMessage;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            ref.read(authNotifierProvider.notifier).clearError();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: const Text('Email Verification'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: UpmindLogo(size: 48, showTagline: false)),
                const SizedBox(height: 28),
                Text(
                  'Verify Your Email',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a 6-digit verification code to',
                  style: AppTypography.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  maskedEmail,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 6-digit OTP input row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    final hasError = displayedError != null;
                    return SizedBox(
                      width: 46,
                      height: 56,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        autofocus: widget.autofocus && index == 0,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: index == 0 ? 6 : 1, // Allow paste in box 0
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: AppColors.card,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: hasError
                                    ? AppColors.error
                                    : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: hasError
                                    ? AppColors.error
                                    : AppColors.primaryBlue,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (val) => _onDigitChanged(index, val),
                        ),
                      );
                  }),
                ),

                if (displayedError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayedError,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                CustomButton(
                  text: 'Verify Email',
                  isLoading: authState.isLoading,
                  onPressed: _handleVerify,
                ),
                const SizedBox(height: 24),

                // Resend Section with Cooldown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: AppTypography.bodySecondary,
                    ),
                    if (_isResending)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (!_canResend)
                      Text(
                        'Resend in ${_secondsRemaining}s',
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _handleResend,
                        child: const Text('Resend Code'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Return to Sign In'),
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).clearError();
                      context.go('/login');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
