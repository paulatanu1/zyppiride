import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animations/animations.dart';
import 'package:zyppi_ride/screens/main_dashboard.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDataLoaded = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (snapshot.exists && mounted) {
      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _userData = data;
        _isDataLoaded = true;
      });
    }
  }

  void _navigateToDashboard() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              FadeThroughTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: const MainDashboard(),
              ),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  void _openEditModal(Map<String, dynamic> userData) {
    final fullNameController =
    TextEditingController(text: userData['fullName'] ?? '');
    DateTime? dob = (userData['dob'] is Timestamp)
        ? (userData['dob'] as Timestamp).toDate()
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Edit Profile",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  readOnly: true,
                  initialValue: userData['email'] ?? '',
                  decoration: const InputDecoration(
                    labelText: "Email (Read-only)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dob ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() => dob = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dob != null
                              ? DateFormat('yyyy-MM-dd').format(dob!)
                              : 'Select Date of Birth',
                          style: const TextStyle(fontFamily: 'Poppins'),
                        ),
                        const Icon(Icons.calendar_today,
                            color: Colors.deepPurple),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade400,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .update({
                      'fullName': fullNameController.text.trim(),
                      'dob': dob,
                    });
                    Navigator.pop(context);
                    _loadUserData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile updated!")),
                    );
                  },
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = _userData;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Profile',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isDataLoaded && userData != null
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: FadeThroughTransition(
          animation: kAlwaysCompleteAnimation,
          secondaryAnimation: kAlwaysDismissedAnimation,
          child: _buildAccordion(userData),
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAccordion(Map<String, dynamic> data) {
    final email = data['email'] ?? 'No email';
    final mobile = data['mobile'] ?? 'No mobile';
    final role = data['role'] ?? 'No role';
    final name = data['fullName'] ?? 'No name';
    final dob = (data['dob'] is Timestamp)
        ? (data['dob'] as Timestamp).toDate()
        : null;

    return Card(
      elevation: 8,
      shadowColor: Colors.deepPurple.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          collapsedBackgroundColor: Colors.deepPurple.shade50,
          backgroundColor: Colors.deepPurple.shade50.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            "Profile Details",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          trailing: Container(
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.keyboard_arrow_down, color: Colors.deepPurple),
          ),
          onExpansionChanged: (expanded) {
            if (expanded) {
              FocusScope.of(context).unfocus();
            }
          },
          childrenPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            const Divider(thickness: 0.5, color: Colors.deepPurpleAccent),
            const SizedBox(height: 8),
            _buildInfoRow("Full Name", name),
            _buildInfoRow("Email", email),
            _buildInfoRow("Mobile", "+91 $mobile"),
            _buildInfoRow("Role", role),
            _buildInfoRow(
              "Date of Birth",
              dob != null ? DateFormat('yyyy-MM-dd').format(dob) : 'Not set',
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              onPressed: () => _openEditModal(data),
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text(
                "Edit Profile",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.deepPurple.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}