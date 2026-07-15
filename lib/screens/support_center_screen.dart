import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/test_mode.dart';
import '../core/theme/brand_colors.dart';

class SupportCenterScreen extends StatefulWidget {
  final String? userId;
  const SupportCenterScreen({super.key, this.userId});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Complaint form controllers
  final _complaintFormKey = GlobalKey<FormState>();
  String _subject = 'Bug or error in the app';
  final _descriptionController = TextEditingController();
  String _priority = 'Medium';
  XFile? _complaintImage;
  bool _isSubmittingComplaint = false;

  // Feedback form controllers
  final _feedbackFormKey = GlobalKey<FormState>();
  double _rating = 4.0;
  final _feedbackController = TextEditingController();
  XFile? _feedbackImage;
  bool _isSubmittingFeedback = false;

  final ImagePicker _picker = ImagePicker();

  final List<String> subjects = [
    'App not responding',
    'Payment issue',
    'Account or login problem',
    'Ride or delivery issue',
    'Incorrect information displayed',
    'Bug or error in the app',
    'Suggestion for improvement',
    'Other technical issues',
  ];

  String? get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // final user = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _pickImageForComplaint() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _complaintImage = picked);
  }

  Future<void> _pickImageForFeedback() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _feedbackImage = picked);
  }

  Future<String?> _uploadFile(XFile file, String path) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);
      final uploadTask = storageRef.putFile(File(file.path));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitComplaint() async {
    if (!_complaintFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit a complaint'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmittingComplaint = true);

    try {
      String? imageUrl;
      if (_complaintImage != null) {
        imageUrl = await _uploadFile(
          _complaintImage!,
          'support/${user.uid}/complaints/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // Ticket IDs are allocated server-side from a transactional counter
      // (W4) — the createSupportTicket callable also writes the document.
      final result = await FirebaseFunctions.instance
          .httpsCallable('createSupportTicket')
          .call<Map<String, dynamic>>({
        'kind': 'complaint',
        'subject': _subject,
        'description': _descriptionController.text.trim(),
        'priority': _priority,
        'imageUrl': imageUrl,
      });
      final ticketId = result.data['ticketId'] as String;

      if (!mounted) return;

      unawaited(showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ Complaint Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your complaint has been registered successfully.'),
              const SizedBox(height: 8),
              Text(
                'Ticket ID: $ticketId',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      ));

      _descriptionController.clear();
      setState(() {
        _complaintImage = null;
        _subject = 'Bug or error in the app';
        _priority = 'Medium';
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComplaint = false);
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (!_feedbackFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit feedback'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmittingFeedback = true);

    try {
      String? imageUrl;
      if (_feedbackImage != null) {
        imageUrl = await _uploadFile(
          _feedbackImage!,
          'support/${user.uid}/feedbacks/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // Reference IDs come from the same transactional counter (W4).
      final result = await FirebaseFunctions.instance
          .httpsCallable('createSupportTicket')
          .call<Map<String, dynamic>>({
        'kind': 'feedback',
        'rating': _rating,
        'message': _feedbackController.text.trim(),
        'imageUrl': imageUrl,
      });
      final feedbackId = result.data['ticketId'] as String;

      if (!mounted) return;

      unawaited(showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ Feedback Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thank you for your feedback!'),
              const SizedBox(height: 8),
              Text(
                'Reference: $feedbackId',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      ));

      _feedbackController.clear();
      setState(() {
        _feedbackImage = null;
        _rating = 4.0;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Widget _buildComplaintForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _complaintFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Register Complaint',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              items: subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _subject = v!),
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              validator: (v) => v == null || v.trim().length < 10
                  ? 'Please provide more details (min 10 chars)'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              items: ['Low', 'Medium', 'High']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isSubmittingComplaint ? null : _pickImageForComplaint,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach Screenshot'),
                ),
                const SizedBox(width: 12),
                if (_complaintImage != null)
                  const Chip(
                    label: Text('Image selected'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingComplaint ? null : _submitComplaint,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmittingComplaint
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Submit Complaint',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: CLEAN Feedback Form (NO Rating Spinner)
  // 🔥 FIXED: Feedback Form (NO setState in Rating!)
  Widget _buildFeedbackForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _feedbackFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Your Feedback',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Rate your experience',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // 🔥 FIXED: Use StatefulBuilder - NO setState!
            StatefulBuilder(
              builder: (context, setRatingState) => RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 36,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  // 🔥 NO setState() - Only local update!
                  setRatingState(() => _rating = rating);
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _feedbackController,
              maxLines: 4,
              enabled: !_isSubmittingFeedback,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please tell us your feedback'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Your feedback',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: 'Tell us what you think...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : _pickImageForFeedback,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach Image'),
                ),
                const SizedBox(width: 12),
                if (_feedbackImage != null)
                  const Chip(
                    label: Text('Image selected'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingFeedback ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmittingFeedback
                    ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Adding feedback...'),
                  ],
                )
                    : const Text(
                  'Submit Feedback',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintsList() {
    final userId = currentUserId;

    if (userId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please sign in to view your complaints',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final complaintsColl = FirebaseFirestore.instance.collection(TestMode.complaintsCollection);

    return StreamBuilder<QuerySnapshot>(
      stream: complaintsColl
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No complaints yet',
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final ticketId = data['ticketId'] ?? doc.id;
            final subject = data['subject'] ?? '—';
            final status = data['status'] ?? 'Pending';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            Color statusColor;
            switch (status.toString().toLowerCase()) {
              case 'resolved':
                statusColor = Colors.green;
                break;
              case 'in progress':
              case 'in_progress':
                statusColor = Colors.orange;
                break;
              default:
                statusColor = Colors.amber;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              elevation: 2,
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ComplaintDetailScreen(ticketDocId: doc.id),
                  ),
                ),
                leading: const Icon(Icons.support_agent, color: BrandColors.brand),
                title: Text(
                  ticketId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(subject),
                    if (createdAt != null)
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeedbackList() {
    final userId = currentUserId;

    if (userId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please sign in to view your feedback',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final feedbackColl = FirebaseFirestore.instance.collection(TestMode.feedbacksCollection);

    return StreamBuilder<QuerySnapshot>(
      stream: feedbackColl
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No feedback submitted yet',
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final feedbackId = data['feedbackId'] ?? doc.id;
            final rating = (data['rating'] ?? 0).toDouble();
            final message = data['message'] ?? '-';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.feedback, color: BrandColors.brand),
                title: Text(
                  feedbackId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                              (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('($rating)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null)
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: BrandColors.brand,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildBrandHeader(context),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                  child: Container(
                    color: BrandColors.bgLight,
                    child: Column(
                      children: [
                        _buildTabBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _buildComplaintForm(),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.history,
                                              color: BrandColors.brand),
                                          SizedBox(width: 8),
                                          Text(
                                            'Your Complaints',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildComplaintsList(),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _buildFeedbackForm(),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.history,
                                              color: BrandColors.brand),
                                          SizedBox(width: 8),
                                          Text(
                                            'Your Feedback',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildFeedbackList(),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildBrandHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/user-dashboard');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Support Center',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: EdgeInsets.zero,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: BrandColors.brand,
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_problem, size: 18),
                  SizedBox(width: 6),
                  Text('Complaints'),
                ],
              ),
            ),
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feedback, size: 18),
                  SizedBox(width: 6),
                  Text('Feedback'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ComplaintDetailScreen remains EXACTLY the same...
class ComplaintDetailScreen extends StatelessWidget {
  final String ticketDocId;
  const ComplaintDetailScreen({super.key, required this.ticketDocId});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection(TestMode.complaintsCollection).doc(ticketDocId);

    return Scaffold(
      backgroundColor: BrandColors.brand,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/support-center');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Complaint Details',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
                child: Container(
                  color: BrandColors.bgLight,
                  child: _buildDetailContent(context, docRef),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
  ) {
    return FutureBuilder<DocumentSnapshot>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Complaint not found',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final ticketId = data['ticketId'] ?? ticketDocId;
          final subject = data['subject'] ?? '-';
          final priority = data['priority'] ?? '-';
          final status = data['status'] ?? 'Pending';
          final description = data['description'] ?? '-';
          final imageUrl = data['imageUrl'];
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          Color statusColor;
          switch (status.toString().toLowerCase()) {
            case 'resolved':
              statusColor = Colors.green;
              break;
            case 'in progress':
            case 'in_progress':
              statusColor = Colors.orange;
              break;
            default:
              statusColor = Colors.amber;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ticket ID',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticketId,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: BrandColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Subject', subject),
                        const Divider(height: 24),
                        _buildDetailRow('Priority', priority),
                        const Divider(height: 24),
                        if (createdAt != null)
                          _buildDetailRow(
                            'Submitted',
                            '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      description,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (imageUrl != null) ...[
                  const Text(
                    'Attachment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Attachment'),
                                backgroundColor: Colors.black,
                              ),
                              backgroundColor: Colors.black,
                              body: Center(
                                child: InteractiveViewer(
                                  child: Image.network(imageUrl),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48),
                                SizedBox(height: 8),
                                Text('Failed to load image'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}