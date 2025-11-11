import 'package:flutter/services.dart';

/// Auto-formats Indian vehicle registration number with hyphens
/// Supports formats like: WB-23-AF-1234, DL-1C-AB-1234, MH-12-AB-1234
class VehicleNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase().replaceAll('-', '');
    
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();
    int cursorOffset = newValue.selection.end;

    // State code (2 letters): XX
    if (text.length >= 1) {
      buffer.write(text.substring(0, text.length >= 2 ? 2 : text.length));
    }

    // Add hyphen after state code
    if (text.length >= 3) {
      buffer.write('-');
      if (cursorOffset >= 2 && oldValue.text.length < newValue.text.length) {
        cursorOffset++;
      }
    }

    // District code (2 digits): 01-99
    if (text.length >= 3) {
      buffer.write(text.substring(2, text.length >= 4 ? 4 : text.length));
    }

    // Add hyphen after district code
    if (text.length >= 5) {
      buffer.write('-');
      if (cursorOffset >= 5 && oldValue.text.length < newValue.text.length) {
        cursorOffset++;
      }
    }

    // Series code (1-2 letters): A or AB
    if (text.length >= 5) {
      buffer.write(text.substring(4, text.length >= 6 ? 6 : text.length));
    }

    // Add hyphen after series code
    if (text.length >= 7) {
      buffer.write('-');
      if (cursorOffset >= 7 && oldValue.text.length < newValue.text.length) {
        cursorOffset++;
      }
    }

    // Vehicle number (4 digits): 0001-9999
    if (text.length >= 7) {
      buffer.write(text.substring(6, text.length >= 10 ? 10 : text.length));
    }

    final formatted = buffer.toString();
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursorOffset.clamp(0, formatted.length),
      ),
    );
  }
}

/// Validator for Indian vehicle registration number
class VehicleNumberValidator {
  static final RegExp _regExp = RegExp(
    r'^[A-Z]{2}-[0-9]{2}-[A-HJ-NP-Z]{1,2}-[0-9]{4}$',
  );

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter registration number';
    }

    if (!_regExp.hasMatch(value)) {
      return 'Invalid format. Use: XX-00-XX-0000';
    }

    return null;
  }
}
