import 'package:flutter/material.dart';

/// यह फ़ंक्शन आपकी AddExpenseScreen में परिभाषित उप-श्रेणी (SubCategory) के आधार पर
/// एक विशिष्ट IconData लौटाता है।
///
/// इसका उपयोग Home Screen, Transaction List और History Screens में किया जा सकता है।
IconData getIconForSubCategory(String subCategory) {
  // इनपुट को सामान्य करें (extra spaces हटाएँ)
  final normalizedSubCategory = subCategory.trim();

  switch (normalizedSubCategory) {

  // --- NEEDS (50%) ---
    case 'Rent/EMI':
      return Icons.home_work_outlined; // घर/किराया
    case 'Groceries/Food':
      return Icons.local_grocery_store_outlined; // किराने का सामान
    case 'Utilities (Elec/Water/Gas)':
      return Icons.lightbulb_outline; // बिजली/गैस
    case 'Transport/Fuel':
      return Icons.directions_car_outlined; // ट्रांसपोर्ट/ईंधन
    case 'Health/Medical':
      return Icons.local_hospital_outlined; // स्वास्थ्य/दवा
    case 'Education':
      return Icons.school_outlined; // शिक्षा
    case 'Other Needs':
      return Icons.shopping_basket_outlined; // अन्य आवश्यकताएँ

  // --- WANTS (30%) ---
    case 'Entertainment/Streaming':
      return Icons.movie_outlined; // मनोरंजन/मूवी/पार्टी
    case 'Dining Out/Cafes':
      return Icons.restaurant_menu_outlined; // बाहर खाना
    case 'Shopping/Clothes':
      return Icons.shopping_bag_outlined; // कपड़े/शॉपिंग
    case 'Travel/Vacation':
      return Icons.airplanemode_active_outlined; // यात्रा/छुट्टियाँ
    case 'Electronics/Gadgets':
      return Icons.devices_other_outlined; // इलेक्ट्रॉनिक्स
    case 'Personal Care/Salon':
      return Icons.cut_outlined; // पर्सनल केयर
    case 'Other Wants':
      return Icons.interests_outlined; // अन्य इच्छाएँ

  // --- SAVING (20%) ---
    case 'Emergency Fund':
      return Icons.safety_divider_outlined; // इमरजेंसी फंड
    case 'Investment (SIP/MF)':
      return Icons.trending_up_outlined; // निवेश/स्टॉक
    case 'Retirement Fund':
      return Icons.elderly_outlined; // रिटायरमेंट
    case 'Specific Goal Contribution':
      return Icons.flag_outlined; // विशिष्ट लक्ष्य योगदान
    case 'Other Saving':
      return Icons.account_balance_wallet_outlined; // अन्य बचत

  // --- DEFAULT ---
    default:
      return Icons.category_outlined; // यदि कोई मैच न हो
  }
}