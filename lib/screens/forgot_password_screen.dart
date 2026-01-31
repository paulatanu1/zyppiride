import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  Future<void> _sendResetEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = ref.read(authServiceProvider);
      final result = await authService.sendPasswordResetEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.success) {
            _emailSent = true;
          } else {
            _errorMessage = result.errorMessage;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _emailSent ? _buildSuccessContent() : _buildFormContent(),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 80,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Check Your Email',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'We have sent a password reset link to:',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _emailController.text.trim(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 24),
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
                  'Click the link in your email to reset your password. The link expires in 1 hour.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Back to Login',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _errorMessage = null;
            });
          },
          child: Text(
            'Didn\'t receive email? Try again',
            style: GoogleFonts.poppins(
              color: Colors.deepPurple,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forgot Password?',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Email field with accessibility
          Semantics(
            label: 'Email address input field',
            child: TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your registered email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _sendResetEmail(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ),

          // Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Semantics(
              label: 'Error: $_errorMessage',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Send Reset Email Button
          Semantics(
            label: 'Send reset link button',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Send Reset Link',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Back to Login
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Back to Login',
                style: GoogleFonts.poppins(
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
