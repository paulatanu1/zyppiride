import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/routes_name.dart';

class BookGoodsCarrierScreen extends ConsumerStatefulWidget {
  final String? initialVehicleType;
  final String? title;

  const BookGoodsCarrierScreen({
    super.key,
    this.initialVehicleType,
    this.title,
  });

  @override
  ConsumerState<BookGoodsCarrierScreen> createState() => _BookGoodsCarrierScreenState();
}

class _BookGoodsCarrierScreenState extends ConsumerState<BookGoodsCarrierScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late String _selectedVehicleType;
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _goodsDescController = TextEditingController();
  double _estimatedWeight = 100;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  final List<Map<String, dynamic>> _vehicleTypes = [
    {'name': 'Bike', 'icon': Icons.two_wheeler, 'capacity': 'Up to 20 kg', 'price': '₹49/km'},
    {'name': 'Auto', 'icon': Icons.electric_rickshaw, 'capacity': 'Up to 100 kg', 'price': '₹15/km'},
    {'name': 'Mini Truck', 'icon': Icons.local_shipping, 'capacity': 'Up to 500 kg', 'price': '₹18/km'},
    {'name': 'Pickup', 'icon': Icons.airport_shuttle, 'capacity': 'Up to 1000 kg', 'price': '₹22/km'},
    {'name': 'Large Truck', 'icon': Icons.fire_truck, 'capacity': 'Up to 3000 kg', 'price': '₹35/km'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select the vehicle type passed from the dashboard tile.
    // Falls back to 'Mini Truck' when opened via the generic goods-transport route.
    _selectedVehicleType = widget.initialVehicleType ?? 'Mini Truck';
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _goodsDescController.dispose();
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Select Vehicle Type'),
                        const SizedBox(height: 12),
                        _buildVehicleTypeSelector(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Pickup & Drop Location'),
                        const SizedBox(height: 12),
                        _buildLocationInputs(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Goods Details'),
                        const SizedBox(height: 12),
                        _buildGoodsDetails(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Schedule (Optional)'),
                        const SizedBox(height: 12),
                        _buildScheduleSection(),
                        const SizedBox(height: 24),
                        _buildEstimatedFare(),
                        const SizedBox(height: 100),
                      ],
                    ),
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
            widget.title ?? 'Book Goods Carrier',
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

  Widget _buildVehicleTypeSelector() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _vehicleTypes.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicleTypes[index];
          final isSelected = _selectedVehicleType == vehicle['name'];
          return Semantics(
            label: '${vehicle['name']}, ${vehicle['capacity']}, ${vehicle['price']}${isSelected ? ', selected' : ''}',
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => setState(() => _selectedVehicleType = vehicle['name']),
              child: Container(
                width: 110,
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
                      vehicle['icon'],
                      size: 36,
                      color: isSelected ? Colors.deepPurple : Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vehicle['name'],
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.deepPurple : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle['capacity'],
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 9,
                        color: isSelected ? Colors.deepPurple.shade300 : Colors.white70,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildGoodsDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _goodsDescController,
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe your goods (e.g., Furniture, Electronics)',
              hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.white70),
              border: InputBorder.none,
            ),
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Text(
            'Estimated Weight: ${_estimatedWeight.toInt()} kg',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
          ),
          Slider(
            value: _estimatedWeight,
            min: 10,
            max: 3000,
            divisions: 60,
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
            onChanged: (value) => setState(() => _estimatedWeight = value),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _scheduledDate != null
                          ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                          : 'Select Date',
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _scheduledTime != null
                          ? _scheduledTime!.format(context)
                          : 'Select Time',
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatedFare() {
    final selectedVehicle = _vehicleTypes.firstWhere(
      (v) => v['name'] == _selectedVehicleType,
    );
    return Container(
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Vehicle',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 14),
              ),
              Text(
                _selectedVehicleType,
                style: TextStyle(fontFamily: 'Poppins', 
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rate',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 14),
              ),
              Text(
                selectedVehicle['price'],
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

  Widget _buildBottomButton() {
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
          label: 'Find carriers button',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bookGoodsCarrier,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Find Carriers',
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  void _bookGoodsCarrier() {
    if (_pickupController.text.isEmpty || _dropController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter pickup and drop locations',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // TODO: Implement booking logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Searching for available carriers...',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
