import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/saved_address_provider.dart';
import '../../widgets/saved_addresses/saved_addresses.dart';

/// Screen for managing saved addresses
class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() =>
      _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  @override
  void initState() {
    super.initState();
    // Load addresses when screen opens
    Future.microtask(() {
      ref.read(savedAddressProvider.notifier).loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => showAddAddressModal(context),
            icon: const Icon(Icons.add),
            tooltip: 'Add Address',
          ),
        ],
      ),
      body: const SavedAddressesList(showHeader: false),
    );
  }
}
