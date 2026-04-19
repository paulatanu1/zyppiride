import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import '../../router/routes_name.dart';
import '../../models/booking_model.dart';
import '../../providers/saved_address_provider.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/saved_addresses/saved_addresses.dart';
import '../../widgets/booking/booking_widgets.dart';

class LocalTransportScreen extends ConsumerStatefulWidget {
  const LocalTransportScreen({super.key});

  @override
  ConsumerState<LocalTransportScreen> createState() => _LocalTransportScreenState();
}

class _LocalTransportScreenState extends ConsumerState<LocalTransportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  String _selectedRideType = 'Regular';
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  int _passengerCount = 1;
  bool _isSearching = false;

  // Location coordinates
  double? _pickupLat;
  double? _pickupLng;
  double? _dropLat;
  double? _dropLng;

  final List<Map<String, dynamic>> _rideTypes = [
    {
      'name': 'Regular',
      'icon': Icons.directions_car,
      'description': 'Affordable everyday rides',
      'multiplier': 1.0,
    },
    {
      'name': 'Premium',
      'icon': Icons.local_taxi,
      'description': 'Comfortable sedans',
      'multiplier': 1.5,
    },
    {
      'name': 'SUV',
      'icon': Icons.airport_shuttle,
      'description': 'Spacious for groups',
      'multiplier': 2.0,
    },
    {
      'name': 'Auto',
      'icon': Icons.electric_rickshaw,
      'description': 'Quick & economical',
      'multiplier': 0.7,
    },
    {
      'name': 'Bike',
      'icon': Icons.two_wheeler,
      'description': 'Beat the traffic',
      'multiplier': 0.5,
    },
  ];

  final List<Map<String, dynamic>> _rentalPackages = [
    {'hours': 1, 'km': 10, 'price': 199},
    {'hours': 2, 'km': 20, 'price': 349},
    {'hours': 4, 'km': 40, 'price': 599},
    {'hours': 8, 'km': 80, 'price': 999},
    {'hours': 12, 'km': 120, 'price': 1399},
  ];

  int _selectedRentalIndex = 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _tabController = TabController(length: 2, vsync: this);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade800,
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOneWayTab(),
                      _buildRentalTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: _buildBottomButton(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Semantics(
            label: 'Go back',
            button: true,
            child: GestureDetector(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RoutesName.userDashboard);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Local Transport',
            style: TextStyle(fontFamily: 'Poppins', 
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.deepPurple,
        unselectedLabelColor: Colors.white,
        labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'One Way'),
          Tab(text: 'Rental'),
        ],
      ),
    );
  }

  Widget _buildOneWayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Select Ride Type'),
          const SizedBox(height: 12),
          _buildRideTypeSelector(),
          const SizedBox(height: 24),
          _buildSavedAddressesSection(),
          _buildSectionTitle('Pickup & Drop Location'),
          const SizedBox(height: 12),
          _buildLocationInputs(),
          const SizedBox(height: 24),
          _buildSectionTitle('Passengers'),
          const SizedBox(height: 12),
          _buildPassengerSelector(),
          const SizedBox(height: 24),
          _buildQuickDestinations(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRentalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Select Ride Type'),
          const SizedBox(height: 12),
          _buildRideTypeSelector(),
          const SizedBox(height: 24),
          _buildSavedAddressesSection(pickupOnly: true),
          _buildSectionTitle('Pickup Location'),
          const SizedBox(height: 12),
          _buildPickupOnly(),
          const SizedBox(height: 24),
          _buildSectionTitle('Select Package'),
          const SizedBox(height: 12),
          _buildRentalPackages(),
          const SizedBox(height: 24),
          _buildRentalInfo(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontFamily: 'Poppins', 
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSavedAddressesSection({bool pickupOnly = false}) {
    final addressState = ref.watch(savedAddressProvider);

    if (addressState.addresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bookmark, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              'Saved Places',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => showAddAddressModal(context),
              child: Text(
                '+ Add',
                style: TextStyle(fontFamily: 'Poppins', 
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Home address
              if (addressState.homeAddress != null)
                _buildSavedAddressChip(
                  addressState.homeAddress!,
                  Icons.home,
                  Colors.blue,
                  pickupOnly,
                ),

              // Work address
              if (addressState.workAddress != null)
                _buildSavedAddressChip(
                  addressState.workAddress!,
                  Icons.work,
                  Colors.orange,
                  pickupOnly,
                ),

              // Other addresses (max 3)
              ...addressState.otherAddresses.take(3).map(
                    (address) => _buildSavedAddressChip(
                      address,
                      Icons.location_on,
                      Colors.purple,
                      pickupOnly,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSavedAddressChip(
    dynamic address,
    IconData icon,
    Color color,
    bool pickupOnly,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Set the address to pickup field
            _pickupController.text = address.address;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${address.displayLabel} selected as pickup',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          onLongPress: pickupOnly
              ? null
              : () {
                  // Set as drop location on long press
                  _dropController.text = address.address;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${address.displayLabel} selected as drop',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      address.displayLabel,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (address.area != null)
                      Text(
                        address.area,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideTypeSelector() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _rideTypes.length,
        itemBuilder: (context, index) {
          final ride = _rideTypes[index];
          final isSelected = _selectedRideType == ride['name'];
          return Semantics(
            label: '${ride['name']} ride type, ${ride['description']}${isSelected ? ', selected' : ''}',
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => setState(() => _selectedRideType = ride['name']),
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: Colors.deepPurple, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ride['icon'],
                      size: 32,
                      color: isSelected ? Colors.deepPurple : Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ride['name'],
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.deepPurple : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ride['multiplier']}x',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 10,
                        color: isSelected ? Colors.deepPurple.shade300 : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildLocationField(
            controller: _pickupController,
            hint: 'Pickup Location',
            icon: Icons.circle,
            iconColor: Colors.green,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Divider(color: Colors.white24),
          ),
          _buildLocationField(
            controller: _dropController,
            hint: 'Drop Location',
            icon: Icons.location_on,
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildPickupOnly() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _buildLocationField(
        controller: _pickupController,
        hint: 'Pickup Location',
        icon: Icons.circle,
        iconColor: Colors.green,
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: '$hint input field',
            child: TextField(
              controller: controller,
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Semantics(
          label: 'Use current location',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white70),
            onPressed: () {
              // TODO: Get current location
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white70),
              const SizedBox(width: 12),
              Text(
                'Number of Passengers',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              _buildCounterButton(Icons.remove, () {
                if (_passengerCount > 1) {
                  setState(() => _passengerCount--);
                }
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_passengerCount',
                  style: TextStyle(fontFamily: 'Poppins', 
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildCounterButton(Icons.add, () {
                if (_passengerCount < 6) {
                  setState(() => _passengerCount++);
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildQuickDestinations() {
    final destinations = [
      {'name': 'Airport', 'icon': Icons.flight},
      {'name': 'Railway Station', 'icon': Icons.train},
      {'name': 'Bus Stand', 'icon': Icons.directions_bus},
      {'name': 'Metro', 'icon': Icons.subway},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quick Destinations'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            final dest = destinations[index];
            return GestureDetector(
              onTap: () {
                _dropController.text = dest['name'] as String;
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      dest['icon'] as IconData,
                      color: Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dest['name'] as String,
                        style: TextStyle(fontFamily: 'Poppins', 
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRentalPackages() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _rentalPackages.length,
        itemBuilder: (context, index) {
          final package = _rentalPackages[index];
          final isSelected = _selectedRentalIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedRentalIndex = index),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: Colors.deepPurple, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${package['hours']}h',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.deepPurple : Colors.white,
                    ),
                  ),
                  Text(
                    '${package['km']} km',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 11,
                      color: isSelected ? Colors.deepPurple.shade300 : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${package['price']}',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.green : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRentalInfo() {
    final selectedPackage = _rentalPackages[_selectedRentalIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Package Details',
                style: TextStyle(fontFamily: 'Poppins', 
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Duration', '${selectedPackage['hours']} Hours'),
          _buildInfoRow('Included KM', '${selectedPackage['km']} km'),
          _buildInfoRow('Extra KM Charge', '₹12/km'),
          _buildInfoRow('Extra Time Charge', '₹100/hr'),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Base Fare',
                style: TextStyle(fontFamily: 'Poppins', 
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${selectedPackage['price']}',
                style: TextStyle(fontFamily: 'Poppins', 
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final isOneWay = _tabController.index == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade800,
            Colors.deepPurple.shade900,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          label: isOneWay ? 'Find rides button' : 'Book rental button',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _bookRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
              ),
              child: _isSearching
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Searching...',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      isOneWay ? 'Find Rides' : 'Book Rental',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _bookRide() async {
    if (_pickupController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter pickup location',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_tabController.index == 0 && _dropController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter drop location',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if user has an active booking
    final canBook = await ref.read(canCreateBookingProvider.future);
    if (!canBook) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You already have an active booking',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                context.goNamed(RoutesName.trackActiveBooking);
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Geocode addresses to get coordinates
      await _geocodeAddresses();

      if (_pickupLat == null || _pickupLng == null) {
        throw Exception('Unable to find pickup location');
      }

      if (_tabController.index == 0 && (_dropLat == null || _dropLng == null)) {
        throw Exception('Unable to find drop location');
      }

      // Calculate estimated distance and duration
      final distance = _calculateDistance();
      final duration = _calculateDuration(distance);

      if (mounted) {
        setState(() => _isSearching = false);

        // Show vehicle selection sheet
        showVehicleSelectionSheet(
          context,
          pickupAddress: _pickupController.text,
          dropAddress: _dropController.text,
          pickupLat: _pickupLat,
          pickupLng: _pickupLng,
          dropLat: _dropLat,
          dropLng: _dropLng,
          vehicleType: _getVehicleType(),
          estimatedDistance: distance,
          estimatedDuration: duration,
          onVehicleSelected: (vehicle, fare) {
            // Show booking confirmation
            showBookingConfirmationSheet(
              context,
              vehicle: vehicle,
              fare: fare,
              pickupLocation: BookingLocation(
                address: _pickupController.text,
                latitude: _pickupLat!,
                longitude: _pickupLng!,
              ),
              dropLocation: BookingLocation(
                address: _dropController.text,
                latitude: _dropLat ?? 0,
                longitude: _dropLng ?? 0,
              ),
              bookingType: _tabController.index == 0
                  ? BookingType.local
                  : BookingType.rental,
              estimatedDistance: distance,
              estimatedDuration: duration,
              onBookingCreated: (booking) {
                // Navigate to tracking screen
                context.goNamed(RoutesName.trackActiveBooking);
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _geocodeAddresses() async {
    // Geocode pickup address
    try {
      final pickupLocations = await locationFromAddress(_pickupController.text);
      if (pickupLocations.isNotEmpty) {
        _pickupLat = pickupLocations.first.latitude;
        _pickupLng = pickupLocations.first.longitude;
      }
    } catch (e) {
      // Silently fail, will be caught in main method
    }

    // Geocode drop address (only for one-way)
    if (_tabController.index == 0 && _dropController.text.isNotEmpty) {
      try {
        final dropLocations = await locationFromAddress(_dropController.text);
        if (dropLocations.isNotEmpty) {
          _dropLat = dropLocations.first.latitude;
          _dropLng = dropLocations.first.longitude;
        }
      } catch (e) {
        // Silently fail, will be caught in main method
      }
    }
  }

  double _calculateDistance() {
    if (_pickupLat == null || _pickupLng == null) return 5.0;
    if (_dropLat == null || _dropLng == null) return 5.0;

    // Haversine formula for distance calculation
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(_dropLat! - _pickupLat!);
    final double dLng = _toRadians(_dropLng! - _pickupLng!);

    final double a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(_pickupLat!)) * _cos(_toRadians(_dropLat!)) *
        _sin(dLng / 2) * _sin(dLng / 2);

    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    final double distance = earthRadius * c;

    // Add 20% for road distance (approximate)
    return (distance * 1.2).clamp(1.0, 500.0);
  }

  int _calculateDuration(double distanceKm) {
    // Assume average speed of 25 km/h in city
    final minutes = (distanceKm / 25 * 60).round();
    return minutes.clamp(5, 600);
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  double _sin(double x) => _sinApprox(x);
  double _cos(double x) => _sinApprox(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _sqrtApprox(x) : 0;
  double _atan2(double y, double x) => _atan2Approx(y, x);

  double _sinApprox(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.14159265359) {
      x -= 6.28318530718;
    }
    while (x < -3.14159265359) {
      x += 6.28318530718;
    }
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _sqrtApprox(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2Approx(double y, double x) {
    if (x > 0) return _atanApprox(y / x);
    if (x < 0 && y >= 0) return _atanApprox(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atanApprox(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _atanApprox(double x) {
    // Simple approximation for atan
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atanApprox(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i < 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  String? _getVehicleType() {
    switch (_selectedRideType.toLowerCase()) {
      case 'regular':
        return 'car';
      case 'premium':
        return 'sedan';
      case 'suv':
        return 'suv';
      case 'auto':
        return 'auto';
      case 'bike':
        return 'bike';
      default:
        return null;
    }
  }
}
