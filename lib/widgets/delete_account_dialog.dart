import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

/// Confirmation + execution flow for permanent account deletion
/// (Google Play User Data policy). Shows a destructive-action dialog,
/// runs the `deleteAccount` Cloud Function with a blocking progress
/// indicator, then routes to the auth screen.
Future<void> showDeleteAccountDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Account?',
        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'This permanently deletes your account and cannot be undone.\n\n'
        'The following will be removed:\n'
        '• Your profile and saved addresses\n'
        '• Registered vehicles and documents\n'
        '• Signed agreements and uploaded photos\n\n'
        'Completed ride records are kept for legal and billing reasons, '
        'but your name and phone number are removed from them.',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Delete Forever',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Blocking progress while the Cloud Function runs.
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  ));

  final authService = AuthService(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
  final error = await authService.deleteAccount();

  if (!context.mounted) return;
  Navigator.pop(context); // dismiss progress dialog

  if (error == null) {
    context.go('/auth');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
  }
}
