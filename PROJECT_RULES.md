# AI Development Rules for FinanceApp

## 1. Import & Analysis Rules
- **Import Check**: নতুন কোনো Model, Provider বা Enum ব্যবহার করলে অবশ্যই ফাইলের শুরুতে সঠিক ইম্পোর্ট আছে কিনা তা নিশ্চিত করতে হবে।
- **Auto-Analysis**: কোড পরিবর্তনের পর অবশ্যই `analyze_file` রান করে চেক করতে হবে কোনো Error বা Warning আছে কিনা।

## 2. State Management (Provider)
- **Watcher vs Reader**: বিল্ড মেথডের ভেতরে ডাটা লিসেন করার জন্য `context.watch<FinanceProvider>()` ব্যবহার করো। কোনো বাটনের ক্লিক বা ফাংশন কলের জন্য `context.read<FinanceProvider>()` ব্যবহার করো।
- **Consistency**: নতুন কোনো ফিচার যোগ করলে `FinanceProvider` এ তার মেথড এবং ডাটা লিস্ট আপডেট করো।

## 3. UI & Styling Rules
- **Hardcoding Prohibition**: কোডে সরাসরি কালার বা টেক্সট স্টাইল (যেমন: `Colors.purple` বা `TextStyle(fontSize: 18)`) ব্যবহার করা যাবে না। অবশ্যই `AppColors`, `AppTypography` এবং `AppSpacing` (যা `app_constants.dart`-এ আছে) ব্যবহার করতে হবে।
- **Responsive Design**: UI তৈরির সময় `SingleChildScrollView` এবং `LayoutBuilder` ব্যবহার করো যাতে ছোট স্ক্রিনে ওভারফ্লো না হয়।

## 4. Model & Database Integrity
- **Model Mapping**: ডাটাবেজ থেকে ডাটা আনা বা পাঠানোর সময় সবসময় Model এর `toMap()` এবং `fromMap()` মেথড ব্যবহার করতে হবে।
- **DB Migration**: যদি Model-এ নতুন কোনো ফিল্ড যোগ করা হয়, তবে অবশ্যই `db_helper.dart`-এ টেবিল স্কিমা এবং `version` আপডেট করতে হবে।

## 5. Workflow Rules
- **Read Before Write**: কোনো ফাইল এডিট করার আগে তার বর্তমান কোড এবং ডিপেন্ডেন্সিগুলো (যেমন: সংশ্লিষ্ট Model বা Provider) একবার দেখে নিতে হবে।
- **Verify Dependencies**: যদি কোনো Model পরিবর্তন করা হয়, তবে সেই Model টি আর কোথায় কোথায় ব্যবহার হয়েছে (যেমন: Screens বা Providers) তা `find_usages` দিয়ে চেক করে সেখানেও আপডেট করতে হবে।

## 6. Google Apps Script Management Rules
- **Script Code Location**: গুগল অ্যাপস স্ক্রিপ্ট (Google Apps Script) এর কোডে কোনো আপডেট বা পরিবর্তন প্রয়োজন হলে চ্যাটের মধ্যে দীর্ঘ কোড না দিয়ে প্রজেক্টের রুট ফোল্ডারে থাকা `google_app_script.js` ফাইলে সরাসরি আপডেট করে দিতে হবে। ইউজার সেখান থেকে সহজে কপি করে গুগল শিটে পেস্ট করবেন।
- **Cleanup on Release**: অ্যাপ ডেভেলপমেন্ট সম্পূর্ণ শেষ হলে রুট ফোল্ডার থেকে `google_app_script.js` ফাইলটি মুছে ফেলা হবে।