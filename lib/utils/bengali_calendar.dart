class BengaliCalendar {
  // Bengali months mapping
  static const Map<int, String> bengaliMonths = {
    1: 'বৈশাখ',    // Boishakh
    2: 'জ্যৈষ্ঠ',   // Jyoishţho
    3: 'আষাঢ়',    // Ashaŗh
    4: 'শ্রাবণ',    // Srabon
    5: 'ভাদ্র',     // Bhadro
    6: 'আশ্বিন',    // Ashshin
    7: 'কার্তিক',   // Kartik
    8: 'অগ্রহায়ণ', // Ogrohayon
    9: 'পৌষ',      // Poush
    10: 'মাঘ',     // Magh
    11: 'ফাল্গুন',  // Falgun
    12: 'চৈত্র',    // Choitro
  };

  static const Map<int, String> bengaliMonthsEnglish = {
    1: 'Boishakh',
    2: 'Jyoishţho',
    3: 'Ashaŗh',
    4: 'Srabon',
    5: 'Bhadro',
    6: 'Ashshin',
    7: 'Kartik',
    8: 'Ogrohayon',
    9: 'Poush',
    10: 'Magh',
    11: 'Falgun',
    12: 'Choitro',
  };

  // Days in each Bengali month (revised calendar - Bangladesh)
  static const Map<int, int> daysInMonth = {
    1: 31,  // Boishakh
    2: 31,  // Jyoishţho
    3: 31,  // Ashaŗh
    4: 31,  // Srabon
    5: 31,  // Bhadro
    6: 30,  // Ashshin
    7: 30,  // Kartik
    8: 30,  // Ogrohayon
    9: 30,  // Poush
    10: 30, // Magh
    11: 30, // Falgun (31 in leap years)
    12: 30, // Choitro
  };

  // Bengali weekday names
  static const Map<int, String> bengaliWeekdays = {
    1: 'সোমবার',     // Monday
    2: 'মঙ্গলবার',   // Tuesday
    3: 'বুধবার',     // Wednesday
    4: 'বৃহস্পতিবার', // Thursday
    5: 'শুক্রবার',   // Friday
    6: 'শনিবার',     // Saturday
    7: 'রবিবার',     // Sunday
  };

  // Convert English digits to Bengali digits
  static String toBengaliNumber(int number) {
    const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return number
        .toString()
        .split('')
        .map((digit) => bengaliDigits[int.parse(digit)])
        .join();
  }

  // Check if a Bengali year is a leap year
  static bool isBengaliLeapYear(int bengaliYear) {
    // Bengali leap year follows Gregorian leap year
    // Bengali year = Gregorian year - 593
    int gregorianYear = bengaliYear + 593;
    return (gregorianYear % 4 == 0 && gregorianYear % 100 != 0) ||
        (gregorianYear % 400 == 0);
  }

  // Convert Gregorian date to Bengali date
  static BengaliDate toBengaliDate(DateTime gregorianDate) {
    // Bengali year starts on April 14 (or April 15 in leap years)
    int gregorianYear = gregorianDate.year;
    int gregorianMonth = gregorianDate.month;
    int gregorianDay = gregorianDate.day;

    // Calculate Bengali year
    int bengaliYear;
    if (gregorianMonth < 4 || (gregorianMonth == 4 && gregorianDay < 14)) {
      bengaliYear = gregorianYear - 594;
    } else {
      bengaliYear = gregorianYear - 593;
    }

    // Calculate the start of Bengali year (April 14)
    DateTime bengaliYearStart = DateTime(gregorianYear, 4, 14);

    // Adjust for leap year (April 15)
    if (_isGregorianLeapYear(gregorianYear) && gregorianMonth > 2) {
      bengaliYearStart = DateTime(gregorianYear, 4, 15);
    }

    // If current date is before Bengali year start, use previous year
    if (gregorianDate.isBefore(bengaliYearStart)) {
      bengaliYear--;
      bengaliYearStart = DateTime(gregorianYear - 1, 4, 14);
      if (_isGregorianLeapYear(gregorianYear - 1)) {
        bengaliYearStart = DateTime(gregorianYear - 1, 4, 15);
      }
    }

    // Calculate days from Bengali year start
    int daysSinceYearStart = gregorianDate.difference(bengaliYearStart).inDays;

    // Calculate Bengali month and day
    int bengaliMonth = 1;
    int bengaliDay = daysSinceYearStart + 1;

    // First 5 months have 31 days each (Boishakh to Bhadro)
    for (int i = 1; i <= 5; i++) {
      if (bengaliDay <= 31) {
        bengaliMonth = i;
        break;
      }
      bengaliDay -= 31;
    }

    // Remaining months have 30 days (except Falgun in leap years)
    if (bengaliMonth == 1 && bengaliDay > 31) {
      for (int i = 6; i <= 12; i++) {
        int daysInCurrentMonth = 30;

        // Falgun (month 11) has 31 days in Bengali leap years
        if (i == 11 && isBengaliLeapYear(bengaliYear)) {
          daysInCurrentMonth = 31;
        }

        if (bengaliDay <= daysInCurrentMonth) {
          bengaliMonth = i;
          break;
        }
        bengaliDay -= daysInCurrentMonth;
      }
    }

    return BengaliDate(
      year: bengaliYear,
      month: bengaliMonth,
      day: bengaliDay,
      monthName: bengaliMonths[bengaliMonth]!,
      monthNameEnglish: bengaliMonthsEnglish[bengaliMonth]!,
      weekday: bengaliWeekdays[gregorianDate.weekday]!,
    );
  }

  static bool _isGregorianLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }
}

class BengaliDate {
  final int year;
  final int month;
  final int day;
  final String monthName;
  final String monthNameEnglish;
  final String weekday;

  BengaliDate({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
    required this.monthNameEnglish,
    required this.weekday,
  });

  String format({bool useBengaliDigits = true}) {
    if (useBengaliDigits) {
      return '${BengaliCalendar.toBengaliNumber(day)} $monthName ${BengaliCalendar.toBengaliNumber(year)}';
    } else {
      return '$day $monthNameEnglish $year';
    }
  }

  String formatShort({bool useBengaliDigits = true}) {
    if (useBengaliDigits) {
      return '${BengaliCalendar.toBengaliNumber(day)} $monthName';
    } else {
      return '$day $monthNameEnglish';
    }
  }
}
