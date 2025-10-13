// lib/screens/agreement_signing_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AgreementSigningScreen extends StatelessWidget {
  final String userId;

  const AgreementSigningScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard?userId=$userId'),
        ),
        title: const Text(
          'Agreement Signing',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign Agreement',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'User ID: $userId',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            // Add your agreement signing functionality here
            const Center(
              child: Text(
                'Agreement signing functionality will be implemented here',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}