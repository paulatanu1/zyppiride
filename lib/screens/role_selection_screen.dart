import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../router/routes_name.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String userId;

  const RoleSelectionScreen({super.key, required this.userId});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _role;
  final _fullNameController = TextEditingController();
  DateTime? _dob;
  bool _termsAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  void _showTermsPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions', style: TextStyle(fontFamily: 'Poppins')),
        content: SingleChildScrollView(
          child: Text(
            '1. Agree to use the app responsibly.\n'
            '2. No sharing of personal data without consent.\n'
            '3. Zyppi Ride reserves the right to terminate accounts for violations.\n'
            '4. All rides are subject to availability and terms of service.',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_role == null) {
        setState(() {
          _errorMessage = 'Please select a role';
        });
        return;
      }
      if (_dob == null) {
        setState(() {
          _errorMessage = 'Please select a date of birth';
        });
        return;
      }
      if (!_termsAccepted) {
        setState(() {
          _errorMessage = 'Please accept the terms & conditions';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'role': _role,
          'fullName': _fullNameController.text.trim(),
          'dob': _dob,
        });

        if (mounted) {
          if (_role == 'User') {
            context.goNamed(RoutesName.userDashboard);
          } else if (_role == 'Vehicle Owner' || _role == 'Driver') {
            context.goNamed(RoutesName.mainDashboard);
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error updating profile: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Role', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Complete Your Profile',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please fill in your details to continue',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Role selection with accessibility
              Semantics(
                label: 'Select your role dropdown',
                child: DropdownButtonFormField<String>(
                  initialValue: _role,
                  hint: Text('Select Role', style: GoogleFonts.poppins()),
                  items: ['User', 'Vehicle Owner', 'Driver'].map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role, style: GoogleFonts.poppins()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _role = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a role' : null,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Full name with accessibility
              Semantics(
                label: 'Full name input field',
                child: TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Date of birth with accessibility
              Semantics(
                label: 'Date of birth selector',
                child: TextFormField(
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  controller: TextEditingController(
                    text: _dob != null ? DateFormat('dd MMM yyyy').format(_dob!) : '',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Select your date of birth',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Semantics(
                      label: 'Open date picker',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                  ),
                  validator: (value) => _dob == null ? 'Please select a date of birth' : null,
                ),
              ),
              const SizedBox(height: 16),

              // Terms checkbox with accessibility
              Semantics(
                label: 'Accept terms and conditions checkbox',
                child: Row(
                  children: [
                    Checkbox(
                      value: _termsAccepted,
                      onChanged: (value) {
                        setState(() {
                          _termsAccepted = value ?? false;
                        });
                      },
                    ),
                    Text('I accept the ', style: GoogleFonts.poppins()),
                    Semantics(
                      label: 'View terms and conditions',
                      button: true,
                      child: InkWell(
                        onTap: _showTermsPopup,
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.poppins(
                            color: Colors.deepPurple,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error message with accessibility
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
                            style: GoogleFonts.poppins(
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

              // Submit button with accessibility
              Semantics(
                label: 'Submit profile button',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
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
                            'Continue',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}