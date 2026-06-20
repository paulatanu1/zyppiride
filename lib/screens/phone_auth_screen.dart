import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../services/auth_service.dart';
import '../router/routes_name.dart';
import '../core/utils/app_logger.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> with CodeAutoFill {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _pinputFocusNode = FocusNode();

  String _selectedCountryCode = '+91';
  String? _appSignature;

  @override
  void initState() {
    super.initState();
    _initSmsListener();
  }

  Future<void> _initSmsListener() async {
    // Get app signature for SMS Retriever API (Android)
    try {
      _appSignature = await SmsAutoFill().getAppSignature;
      AppLogger.debug('App Signature: $_appSignature', tag: 'PhoneAuth');
    } catch (e) {
      AppLogger.error('Error getting app signature', tag: 'PhoneAuth', error: e);
    }
  }

  void _startListeningForOtp() {
    // Start listening for SMS
    listenForCode();

    // Also use SmsAutoFill for broader compatibility
    SmsAutoFill().listenForCode();
  }

  @override
  void codeUpdated() {
    // Called when OTP is automatically detected
    if (code != null && code!.length == 6) {
      setState(() {
        _otpController.text = code!;
      });
      // Auto-verify after a short delay to let user see the OTP
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _otpController.text.length == 6) {
          _verifyOtp();
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _pinputFocusNode.dispose();
    cancel(); // Cancel SMS listener
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  /// Validates phone number format based on country code
  String? _validatePhoneFormat(String phone, String countryCode) {
    // Remove any non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // Define validation rules for different countries
    switch (countryCode) {
      case '+91': // India
        if (digits.length != 10) {
          return 'Indian numbers must be 10 digits';
        }
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
          return 'Invalid Indian mobile number';
        }
        break;
      case '+1': // US/Canada
        if (digits.length != 10) {
          return 'US/Canada numbers must be 10 digits';
        }
        if (!RegExp(r'^[2-9]\d{9}$').hasMatch(digits)) {
          return 'Invalid US/Canada number format';
        }
        break;
      case '+44': // UK
        if (digits.length < 10 || digits.length > 11) {
          return 'UK numbers must be 10-11 digits';
        }
        break;
      case '+61': // Australia
        if (digits.length != 9 && digits.length != 10) {
          return 'Australian numbers must be 9-10 digits';
        }
        break;
      default:
        // Generic validation for other countries
        if (digits.length < 8 || digits.length > 15) {
          return 'Phone number must be 8-15 digits';
        }
    }
    return null;
  }

  Future<void> _sendOtp() async {
    if (_phoneFormKey.currentState!.validate()) {
      final phoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';

      // Start listening for OTP before sending
      _startListeningForOtp();

      await ref.read(phoneAuthNotifierProvider.notifier).sendOtp(phoneNumber);

      // Focus on OTP input after code is sent
      final phoneAuthState = ref.read(phoneAuthNotifierProvider);
      if (phoneAuthState.status == PhoneAuthStatus.codeSent) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _pinputFocusNode.requestFocus();
          }
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    final result = await ref
        .read(phoneAuthNotifierProvider.notifier)
        .verifyOtp(_otpController.text.trim());

    if (result.isSuccess && mounted) {
      // Cancel SMS listener on success
      cancel();
      SmsAutoFill().unregisterListener();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      if (result.isNewUser) {
        // New user - navigate to role selection
        context.goNamed(
          RoutesName.roleSelection,
          queryParameters: {'userId': result.user!.uid},
        );
      } else {
        // Existing user - check their role and navigate accordingly
        final authService = ref.read(authServiceProvider);
        final role = await authService.getUserRole(result.user!.uid);
        if (!mounted) return;
        if (role == 'Driver' || role == 'Vehicle Owner') {
          context.goNamed(RoutesName.mainDashboard);
        } else if (role == 'User') {
          context.goNamed(RoutesName.userDashboard);
        } else {
          // No role set - go to role selection
          context.goNamed(
            RoutesName.roleSelection,
            queryParameters: {'userId': result.user!.uid},
          );
        }
      }
    }
  }

  void _resendOtp() {
    _otpController.clear();
    _sendOtp();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent again!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneAuthState = ref.watch(phoneAuthNotifierProvider);
    final isOtpSent = phoneAuthState.status == PhoneAuthStatus.codeSent ||
        phoneAuthState.status == PhoneAuthStatus.verifying;

    return Scaffold(
      appBar: AppBar(
        title: Text('Phone Login', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: Semantics(
          label: 'Go back',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(phoneAuthNotifierProvider.notifier).reset();
              context.pop();
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOtpSent ? 'Verify OTP' : 'Enter Phone Number',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOtpSent
                  ? 'Enter the 6-digit code sent to your phone'
                  : 'We will send you a verification code',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            if (!isOtpSent) ...[
              _buildPhoneInputSection(phoneAuthState),
            ] else ...[
              _buildOtpInputSection(phoneAuthState),
            ],

            const SizedBox(height: 32),

            // Info text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isOtpSent
                          ? 'OTP will be auto-filled when SMS is received'
                          : 'Standard SMS charges may apply',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputSection(PhoneAuthState phoneAuthState) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country Code Dropdown with accessibility
              Semantics(
                label: 'Country code selector',
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      items: const [
                        DropdownMenuItem(value: '+91', child: Text('+91')),
                        DropdownMenuItem(value: '+1', child: Text('+1')),
                        DropdownMenuItem(value: '+44', child: Text('+44')),
                        DropdownMenuItem(value: '+61', child: Text('+61')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCountryCode = value ?? '+91';
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Phone Number Input with accessibility
              Expanded(
                child: Semantics(
                  label: 'Phone number input field',
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '9876543210',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      // Validate phone format based on country code
                      final validationError = _validatePhoneFormat(value, _selectedCountryCode);
                      if (validationError != null) {
                        return validationError;
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error Message
          if (phoneAuthState.errorMessage != null)
            _buildErrorMessage(phoneAuthState.errorMessage!),

          // Send OTP Button with accessibility
          Semantics(
            label: 'Send OTP button',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: phoneAuthState.isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: phoneAuthState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Send OTP',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInputSection(PhoneAuthState phoneAuthState) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: TextStyle(fontFamily: 'Poppins', 
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.deepPurple,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple),
        color: Colors.deepPurple.shade50,
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
    );

    return Column(
      children: [
        // Display phone number
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                '$_selectedCountryCode ${_phoneController.text}',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
              const Spacer(),
              Semantics(
                label: 'Change phone number',
                button: true,
                child: TextButton(
                  onPressed: () {
                    _otpController.clear();
                    ref.read(phoneAuthNotifierProvider.notifier).reset();
                  },
                  child: Text(
                    'Change',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.deepPurple),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // OTP Input with Pinput and accessibility
        Semantics(
          label: 'Enter 6-digit OTP code',
          child: Pinput(
            length: 6,
            controller: _otpController,
            focusNode: _pinputFocusNode,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            errorPinTheme: errorPinTheme,
            pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
            showCursor: true,
            autofocus: true,
            hapticFeedbackType: HapticFeedbackType.lightImpact,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            onCompleted: (pin) {
              // Auto-verify only when not already loading (prevents double-fire
              // if user taps the manual verify button while onCompleted fires)
              if (!phoneAuthState.isLoading) _verifyOtp();
            },
            onChanged: (value) {
              // Clear error when user types
              if (phoneAuthState.errorMessage != null && value.isNotEmpty) {
                // This will trigger rebuild without error
              }
            },
          ),
        ),

        const SizedBox(height: 24),

        // Auto-fill indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'OTP will auto-fill from SMS',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Resend OTP with accessibility
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey[600]),
            ),
            Semantics(
              label: 'Resend OTP button',
              button: true,
              child: TextButton(
                onPressed: phoneAuthState.isLoading ? null : _resendOtp,
                child: Text(
                  'Resend',
                  style: TextStyle(fontFamily: 'Poppins', 
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Error Message
        if (phoneAuthState.errorMessage != null)
          _buildErrorMessage(phoneAuthState.errorMessage!),

        const SizedBox(height: 16),

        // Verify OTP Button with accessibility
        Semantics(
          label: 'Verify OTP button',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: phoneAuthState.isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: phoneAuthState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Verify OTP',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message) {
    return Semantics(
      label: 'Error: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
