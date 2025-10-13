// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// // import 'dashboard_screen.dart'; // Import the new dashboard
//
// class RoleSelectionScreen extends StatefulWidget {
//   final String userId;
//
//   const RoleSelectionScreen({super.key, required this.userId});
//
//   @override
//   State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
// }
//
// class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
//   final _formKey = GlobalKey<FormState>();
//   String? _role;
//   final _fullNameController = TextEditingController();
//   DateTime? _dob;
//   bool _termsAccepted = false;
//   bool _isLoading = false;
//   String? _errorMessage;
//
//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _dob ?? DateTime.now(),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null && picked != _dob) {
//       setState(() {
//         _dob = picked;
//       });
//     }
//   }
//
//   void _showTermsPopup() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Terms & Conditions', style: TextStyle(fontFamily: 'Poppins')),
//         content: SingleChildScrollView(
//           child: Text(
//             '1. Agree to use the app responsibly.\n'
//             '2. No sharing of personal data without consent.\n'
//             '3. Zyppi Ride reserves the right to terminate accounts for violations.\n'
//             '4. All rides are subject to availability and terms of service.',
//             style: const TextStyle(fontFamily: 'Poppins'),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => context.go('/dashboard?userId=$userId'),
//             child: const Text('Close', style: TextStyle(fontFamily: 'Poppins')),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _submit() async {
//     if (_formKey.currentState!.validate()) {
//       if (_role == null) {
//         setState(() {
//           _errorMessage = 'Please select a role';
//         });
//         return;
//       }
//       if (_dob == null) {
//         setState(() {
//           _errorMessage = 'Please select a date of birth';
//         });
//         return;
//       }
//       if (!_termsAccepted) {
//         setState(() {
//           _errorMessage = 'Please accept the terms & conditions';
//         });
//         return;
//       }
//
//       setState(() {
//         _isLoading = true;
//         _errorMessage = null;
//       });
//       try {
//         await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
//           'role': _role,
//           'fullName': _fullNameController.text.trim(),
//           'dob': _dob,
//         });
//
//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => DashboardScreen(userId: widget.userId),
//             ),
//           );
//         }
//       } catch (e) {
//         setState(() {
//           _errorMessage = 'Error updating profile: $e';
//         });
//       } finally {
//         if (mounted) {
//           setState(() {
//             _isLoading = false;
//           });
//         }
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _fullNameController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Select Role', style: TextStyle(fontFamily: 'Poppins')),
//         backgroundColor: Colors.deepPurple,
//         foregroundColor: Colors.white,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               Text(
//                 'Complete Your Profile',
//                 style: const TextStyle(
//                   fontFamily: 'Poppins',
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.deepPurple,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               DropdownButtonFormField<String>(
//                 value: _role,
//                 hint: const Text('Select Role', style: TextStyle(fontFamily: 'Poppins')),
//                 items: ['User', 'Vehicle Owner', 'Driver'].map((String role) {
//                   return DropdownMenuItem<String>(
//                     value: role,
//                     child: Text(role, style: const TextStyle(fontFamily: 'Poppins')),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _role = value;
//                   });
//                 },
//                 validator: (value) => value == null ? 'Please select a role' : null,
//                 decoration: InputDecoration(
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _fullNameController,
//                 decoration: InputDecoration(
//                   labelText: 'Full Name',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your full name';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 readOnly: true,
//                 controller: TextEditingController(
//                   text: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
//                 ),
//                 decoration: InputDecoration(
//                   labelText: 'Date of Birth',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   suffixIcon: IconButton(
//                     icon: const Icon(Icons.calendar_today),
//                     onPressed: () => _selectDate(context),
//                   ),
//                 ),
//                 validator: (value) => _dob == null ? 'Please select a date of birth' : null,
//               ),
//               const SizedBox(height: 16),
//               Row(
//                 children: [
//                   Checkbox(
//                     value: _termsAccepted,
//                     onChanged: (value) {
//                       setState(() {
//                         _termsAccepted = value ?? false;
//                       });
//                     },
//                   ),
//                   const Text('I accept the ', style: TextStyle(fontFamily: 'Poppins')),
//                   InkWell(
//                     onTap: _showTermsPopup,
//                     child: const Text(
//                       'Terms & Conditions',
//                       style: TextStyle(
//                         fontFamily: 'Poppins',
//                         color: Colors.blue,
//                         decoration: TextDecoration.underline,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               if (_errorMessage != null)
//                 Text(
//                   _errorMessage!,
//                   style: const TextStyle(
//                     fontFamily: 'Poppins',
//                     color: Colors.red,
//                   ),
//                 ),
//               const SizedBox(height: 20),
//               Center(
//                 child: _isLoading
//                     ? const CircularProgressIndicator()
//                     : ElevatedButton(
//                         onPressed: _submit,
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
//                           backgroundColor: Colors.deepPurple,
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                         ),
//                         child: const Text(
//                           'Submit',
//                           style: TextStyle(
//                             fontFamily: 'Poppins',
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }