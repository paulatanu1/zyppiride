// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:go_router/go_router.dart';
//
// class VerifyOTPScreen extends StatefulWidget {
//   final String userId;
//   final String email;
//
//   const VerifyOTPScreen({super.key, required this.userId, required this.email});
//
//   @override
//   State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
// }
//
// class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
//   final _otpController = TextEditingController();
//   bool _isLoading = false;
//   String? _errorMessage;
//
//   Future<void> _verifyOTP() async {
//     if (_otpController.text.length != 6) {
//       setState(() {
//         _errorMessage = 'Please enter a 6-digit OTP';
//       });
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final doc = await FirebaseFirestore.instance
//           .collection('otps')
//           .doc(widget.userId)
//           .get();
//
//       if (!doc.exists) {
//         setState(() {
//           _errorMessage = 'OTP not found. Please request a new one.';
//         });
//         return;
//       }
//
//       final data = doc.data()!;
//       final storedOTP = data['otp'] as String;
//       final expiresAt = (data['expiresAt'] as Timestamp).toDate();
//
//       if (_otpController.text != storedOTP) {
//         setState(() {
//           _errorMessage = 'Invalid OTP. Please try again.';
//         });
//         return;
//       }
//
//       if (DateTime.now().isAfter(expiresAt)) {
//         setState(() {
//           _errorMessage = 'OTP has expired. Please request a new one.';
//         });
//         return;
//       }
//
//       // Mark user as verified in Firestore
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(widget.userId)
//           .update({'verified': true});
//
//       // Clean up OTP document
//       await doc.reference.delete();
//
//       // Navigate to RoleSelectionScreen
//       if (context.mounted) {
//         context.go('/role-selection?userId=${widget.userId}');
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Verification failed: $e';
//       });
//     } finally {
//       if (context.mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _resendOTP() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final callable = FirebaseFunctions.instance.httpsCallable('sendEmailOTP');
//       await callable.call({'email': widget.email, 'userId': widget.userId});
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('New OTP sent to your email!')),
//         );
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to resend OTP: $e';
//       });
//     } finally {
//       if (context.mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _otpController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Verify OTP', style: TextStyle(fontFamily: 'Poppins')),
//         backgroundColor: Colors.deepPurple,
//         foregroundColor: Colors.white,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Enter OTP',
//               style: TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.deepPurple,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               'A 6-digit OTP has been sent to ${widget.email}',
//               style: const TextStyle(fontFamily: 'Poppins', fontSize: 16),
//             ),
//             const SizedBox(height: 20),
//             TextFormField(
//               controller: _otpController,
//               decoration: InputDecoration(
//                 labelText: 'OTP',
//                 prefixIcon: const Icon(Icons.lock),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               keyboardType: TextInputType.number,
//               maxLength: 6,
//               textInputAction: TextInputAction.done,
//               onFieldSubmitted: (_) => _verifyOTP(),
//             ),
//             const SizedBox(height: 20),
//             if (_errorMessage != null)
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(12),
//                 margin: const EdgeInsets.only(bottom: 20),
//                 decoration: BoxDecoration(
//                   color: Colors.red.shade50,
//                   border: Border.all(color: Colors.red.shade300),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.error_outline, color: Colors.red.shade600),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         _errorMessage!,
//                         style: TextStyle(
//                           fontFamily: 'Poppins',
//                           color: Colors.red.shade700,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             Center(
//               child: _isLoading
//                   ? const CircularProgressIndicator()
//                   : ElevatedButton(
//                 onPressed: _verifyOTP,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 40,
//                     vertical: 16,
//                   ),
//                   backgroundColor: Colors.deepPurple,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                 ),
//                 child: const Text(
//                   'Verify OTP',
//                   style: TextStyle(
//                     fontFamily: 'Poppins',
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Center(
//               child: TextButton(
//                 onPressed: _resendOTP,
//                 child: const Text(
//                   'Resend OTP',
//                   style: TextStyle(
//                     fontFamily: 'Poppins',
//                     color: Colors.deepPurple,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }