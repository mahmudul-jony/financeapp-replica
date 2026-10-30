import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// =============================================================================
// MINIMAL DESIGN SYSTEM (Clean Tone) - কেন্দ্রীয় নিয়ন্ত্রণ কেন্দ্র
// =============================================================================
// এই ফাইলটি আপনার অ্যাপের "CSS Variables" এর মতো কাজ করে। 
// অ্যাপের প্রতিটি টেক্সট, কালার এবং গ্যাপ এখান থেকে নিয়ন্ত্রিত হয়।

class AppFormat {
  static final NumberFormat _formatter = NumberFormat('#,##,##0.00', 'en_IN');

  static String currency(double amount) {
    // Format with standard comma separation and 2 decimal places
    return '৳${_formatter.format(amount)}';
  }
}

class AppColors {
  // --- ১. মেইন থিম কালার (Primary Brand Colors) ---
  // মেইন অ্যাকশন বাটন, সিলেক্টেড আইটেম এবং ব্র্যান্ডিং এলিমেন্টের জন্য।
  static const primaryPurple = Color(0xFF7F3DFF); 
  static const softLightPurple = Color(0xFFF1E9FC);

  // --- ২. সারফেস এবং ব্যাকগ্রাউন্ড (Surface & Backgrounds) ---
  // Scaffold ব্যাকগ্রাউন্ড: পুরো অ্যাপের সাধারণ ব্যাকগ্রাউন্ড গ্রে টোন।
  static const backgroundGrey = Color(0xFFEFEFEF);
  // কার্ড ব্যাকগ্রাউন্ড: ড্যাশবোর্ড এবং ডিটেইলস পেজের ডার্ক কার্ডের জন্য।
  static const cardBackground = Color(0xFF161719); 
  // পিওর হোয়াইট: কন্টেইনার এবং ইনপুট ফিল্ডের ব্যাকগ্রাউন্ড।
  static const backgroundWhite = Color(0xFFFFFFFF); 
  
  // --- ৩. টেক্সট এবং বর্ডার (Typography & Borders) ---
  // টাইটেল এবং গুরুত্বপূর্ণ ফিগারের জন্য গাঢ় কালো।
  static const primaryText = Color(0xFF0D0E0F); 
  // লেবেল এবং অপেক্ষাকৃত কম গুরুত্বপূর্ণ তথ্যের জন্য মিউটেড গ্রে।
  static const secondaryText = Color(0xFF91919F); 
  static const mutedWhite = Color(0xFFE3E5E5);
  // বর্ডার: ইনপুট ফিল্ড এবং ডিভাইডারের জন্য অত্যন্ত সূক্ষ্ম গ্রে।
  static const borderGrey = Color(0xFFF1F1FA); 

  // --- ৪. স্ট্যাটাস এবং অ্যালার্ট (Status & Alerts) ---
  static const expenseAlertBackground = Color(0xFFFFEAEA);
  static const expenseAlertText = Color(0xFFFD3C4A); 
  static const incomeGreen = Color(0xFF00A86B);     
  static const graphPurple = Color(0xFF7F3DFF);     

  // --- ৫. ড্যাশবোর্ড গ্রেডিয়েন্ট (Visual Flair) ---
  static const dashboardGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFE6E2FD),
    Color(0xFFCFC4FF),
    Color(0xFFB7A7FF),
    Color(0xFF9E8AFD),
    Color(0xFF876BFC),
    Color(0xFF7252FD),
    Color(0xFF7252FD),
  ];
  static const dashboardOfflineGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFE6E6E6),
    Color(0xFFCECECE),
    Color(0xFFB6B6B6),
    Color(0xFF9D9D9D),
    Color(0xFF848484),
    Color(0xFF6F6F6F),
    Color(0xFF6F6F6F),
  ];
  static const dashboardStops = [0.0, 0.12, 0.25, 0.38, 0.50, 0.62, 0.75, 1.0];

  // --- ৬. Inspiration Palette ---
  static const paleBlue = Color(0xFFE8F1FF);
  static const paleYellow = Color(0xFFFFF9E5);
  static const accentBlue = Color(0xFF5D9BFF);
}

class AppSpacing {
  // --- ১. গ্লোবাল প্যাডিং (Layout Constraints) ---
  // স্ক্রিনের চারপাশের মূল সীমানা বা প্যাডিং।
  static const double screenPadding = 12.0; 
  // এলিমেন্টগুলোর মাঝখানের স্ট্যান্ডার্ড গ্যাপ।
  static const double elementGap = 12.0;
  
  // --- ২. ভার্টিকাল গ্যাপ (Vertical Margins) ---
  // ফর্ম ফিল্ড বা লিস্ট আইটেমের মাঝখানে ব্যবহারের জন্য।
  static const verticalGap = SizedBox(height: 8);
  static const largeVerticalGap = SizedBox(height: 12); 
  static const smallVerticalGap = SizedBox(height: 6);  
  
  // --- ৩. হরাইজন্টাল গ্যাপ (Horizontal Margins) ---
  // পাশাপাশি থাকা আইকন বা টেক্সটের মাঝখানে ব্যবহারের জন্য।
  static const horizontalGap = SizedBox(width: 8);

  // --- ৪. এজ ইনসেট শর্টকাট (EdgeInset Helpers) ---
  static const screenPaddingInsets = EdgeInsets.all(screenPadding);
  static const elementPaddingInsets = EdgeInsets.all(elementGap);
}

class AppRadius {
  // --- ১. কর্নার রেডিয়াস লেভেল (Corner Rounding) ---
  // বাটন এবং ছোট ড্রপডাউনের জন্য।
  static const double small = 8.0;
  // মাঝারি সাইজের কার্ড বা বক্সের জন্য।
  static const double medium = 8.0;
  // ড্যাশবোর্ড এবং বড় ডিটেইলস কার্ডের জন্য।
  static const double large = 20.0;  
  // গোল সার্কেল বা পিল বাটন তৈরির জন্য।
  static const double circular = 999.0;
  
  // --- ২. রেডিয়াস অবজেক্টস (Direct Usage) ---
  static final borderRadiusLarge = BorderRadius.circular(large);
  static final borderRadiusMedium = BorderRadius.circular(medium);
  static final borderRadiusSmall = BorderRadius.circular(small);
}

class AppTypography {
  // অ্যাপের একমাত্র অফিসিয়াল ফন্ট ফ্যামিলি।
  static const String fontFamily = 'Roboto';

  // --- ১. হেডলাইন এবং টাইটেল (Headlines) ---
  static const title = TextStyle(
    color: AppColors.primaryText, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5,
  );

  // --- ২. লেবেল এবং সাব-টাইটেল (Labels) ---
  static const subTitle = TextStyle(
    color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.w500,
  );

  // --- ৩. বডি টেক্সট (Content) ---
  static const body = TextStyle(
    color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w400,
  );

  // --- ৪. ক্যাপশন এবং মিউটেড টেক্সট (Secondary Info) ---
  static const caption = TextStyle(
    color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.w500,
  );

  // --- ৫. ডাইনামিক অ্যামাউন্ট (Financial Figures) ---
  static const largeAmount = TextStyle(
    color: AppColors.primaryText, fontSize: 40, fontWeight: FontWeight.w600, letterSpacing: -1,
  );

  // --- ৬. ডার্ক ব্যাকগ্রাউন্ডের জন্য ভেরিয়েশন (White Text Variants) ---
  static const titleWhite = TextStyle(
    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
  );
  static const bodyWhite = TextStyle(
    color: Colors.white, fontSize: 14,
  );
  static const captionMuted = TextStyle(
    color: AppColors.mutedWhite, fontSize: 11,
  );
}
