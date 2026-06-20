import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/routes_name.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          // Navigate based on user role
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
        } else {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isGoogleLoading = false;
      });

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in successful!')),
        );

        if (result.isNewUser) {
          // New user - navigate to role selection using GoRouter
          context.goNamed(
            RoutesName.roleSelection,
            queryParameters: {'userId': result.user!.uid},
          );
        } else {
          // Existing user - check their role and navigate accordingly
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
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
        });
      }
    }
  }

  void _navigateToPhoneAuth() {
    context.pushNamed(RoutesName.phoneAuth);
  }

  void _navigateToForgotPassword() {
    context.pushNamed(RoutesName.forgotPassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Social Login Buttons
            _buildSocialLoginSection(),

            const SizedBox(height: 24),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(fontFamily: 'Poppins', 
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 24),

            // Email/Password Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email field with accessibility
                  Semantics(
                    label: 'Email address input field',
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password field with accessibility
                  Semantics(
                    label: 'Password input field',
                    child: TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: Semantics(
                          label: _obscurePassword ? 'Show password' : 'Hide password',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Forgot Password - Now linked!
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      label: 'Forgot password link',
                      button: true,
                      child: TextButton(
                        onPressed: _navigateToForgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(fontFamily: 'Poppins', 
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
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

                  // Login Button with accessibility
                  Semantics(
                    label: 'Login button',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
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
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Login',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(fontFamily: 'Poppins', color: Colors.grey[600]),
                      ),
                      Semantics(
                        label: 'Sign up link',
                        button: true,
                        child: TextButton(
                          onPressed: () {
                            context.pushNamed(RoutesName.registration);
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(fontFamily: 'Poppins', 
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLoginSection() {
    return Column(
      children: [
        // Google Sign-In Button with accessibility
        Semantics(
          label: 'Sign in with Google button',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGoogleLoading ? null : _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isGoogleLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Image.network(
                      'https://www.google.com/favicon.ico',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.g_mobiledata,
                            size: 24, color: Colors.red);
                      },
                    ),
              label: Text(
                'Continue with Google',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Phone Sign-In Button with accessibility
        Semantics(
          label: 'Sign in with phone number button',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _navigateToPhoneAuth,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.phone, color: Colors.green[700], size: 24),
              label: Text(
                'Continue with Phone',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
