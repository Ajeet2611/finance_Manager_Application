# Personal Finance Manager Application  


**Document Type:** Academic Project Report  
**Application:** Finance Manager (Flutter/Dart)  
**Backend:** Firebase (Authentication, Cloud Firestore, Storage)  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Data Flow Description](#3-data-flow-description)
4. [Function-wise Module Explanation](#4-function-wise-module-explanation)
5. [Database Schema Description](#5-database-schema-description)
6. [References](#6-references)

---

## 1. Executive Summary

The Personal Finance Manager is a cross-platform mobile application built with **Flutter** and **Dart**, using **Firebase** as the backend. The system enables users to manage monthly budgets using the **50/30/20 rule** (50% Needs, 30% Wants, 20% Savings), track expenses with automatic category detection, set savings goals, manage recurring bills with reminders, and view analytical reports. The application supports **localization** (English and Hindi), **theme switching** (light/dark), and **local notifications** for bill reminders. Data is persisted in **Cloud Firestore** (NoSQL); user identity is managed by **Firebase Authentication**, and profile images are stored in **Firebase Storage**.

---

## 2. System Architecture

The system follows a **layered architecture** with clear separation between presentation, business logic, and data access. The high-level structure is described below.

### 2.1 Architectural Layers

| Layer | Components | Responsibility |
|-------|------------|----------------|
| **Presentation (UI)** | Screens, Widgets, Theme | User interaction, navigation, visual feedback |
| **State Management** | Provider (SettingsProvider), Local State (setState) | Theme, locale, and screen-level state |
| **Business Logic** | Screen logic, helpers, validators | Validation, calculations (50/30/20, goals), category detection |
| **Services** | NotificationService | Local notification scheduling and cancellation |
| **Data Access** | Firebase Auth, Cloud Firestore, Firebase Storage, SharedPreferences | Authentication, CRUD, file storage, local preferences |

### 2.2 Component Diagram (Conceptual)

```
                    +------------------+
                    |     main.dart    |
                    |  (MyApp, init)   |
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |                   |                   |
         v                   v                   v
+----------------+  +----------------+  +----------------------+
| SettingsProvider|  | Notification  |  | Firebase.initialize |
| (Theme, Locale) |  | Service.init |  | App()                 |
+--------+--------+  +-------+-------+  +----------+-----------+
         |                   |                     |
         v                   v                     v
+----------------+  +----------------+  +----------------------+
| MaterialApp    |  | SplashScreen   |  | Auth, Firestore,      |
| (theme, locale)|  | (4s → route)  |  | Storage (backend)    |
+--------+--------+  +-------+-------+  +----------+-----------+
         |                   |                     |
         |         +---------+---------+             |
         |         |                   |             |
         v         v                   v             v
+----------------+  +----------------+  +----------------------+
| WelcomeScreen  |  | HomeScreen     |  | All screens use     |
| LoginScreen    |  | (MainScaffold) |  | _auth, _firestore    |
| SignupScreen   |  | 5-tab nav      |  | for data operations  |
+----------------+  +----------------+  +----------------------+
```

### 2.3 Module Dependency Overview

- **main.dart** depends on: Flutter, Firebase Core, Provider, NotificationService, SettingsProvider, SplashScreen.
- **SplashScreen** depends on: Firebase Auth (currentUser), WelcomeScreen, HomeScreen.
- **WelcomeScreen** depends on: LoginScreen, SignupScreen (navigation only).
- **LoginScreen / SignupScreen** depend on: Firebase Auth, SharedPreferences (remember me), Firestore (signup: users collection), HomeScreen.
- **HomeScreen** wraps **MainScaffold**, which holds: Firebase Auth, Firestore, HomeBody, AnalysisScreen, GoalSettingScreen, ProfileScreen, AddExpenseScreen (via FAB).
- **HomeBody** depends on: Firestore streams (monthly_records, transactions), CategoryTransactionsScreen, callbacks from MainScaffold (setBaseSalary, addExtraIncome, deleteTransaction).
- **AddExpenseScreen** depends on: Firebase Auth, Firestore (monthly_records, transactions), keyword-based category detection.
- **AnalysisScreen** depends on: Firebase Auth, Firestore (monthly_records with range query), fl_chart.
- **GoalSettingScreen** depends on: Firebase Auth, Firestore (saving_goals).
- **ProfileScreen** depends on: Firebase Auth, Provider (SettingsProvider), BillSetupScreen, EditProfileScreen, WelcomeScreen (logout).
- **EditProfileScreen** depends on: Firebase Auth, Firebase Storage, ImagePicker.
- **BillSetupScreen** depends on: Firebase Auth, Firestore (artifacts/{appId}/users/{uid}/user_bills), NotificationService.
- **NotificationScreen** depends on: Firebase Auth, Firestore (same path for user_bills and saving_goals).
- **CategoryTransactionsScreen** depends on: Firebase Auth, Firestore (monthly_records/{docId}/transactions with category + time filters).
- **NotificationService** depends on: flutter_local_notifications, timezone (no Firebase).
- **SettingsProvider** depends on: SharedPreferences (language), not Firebase.

### 2.4 Key Design Decisions

- **Single main scaffold:** Post-login experience is centralized in `MainScaffold` with a bottom navigation bar (Home, Reports, Goals, Alerts, Profile) and an IndexedStack to preserve tab state.
- **Stream-based reactivity:** Firestore `snapshots()` streams drive UI updates (e.g. `StreamBuilder`) so that data changes are reflected in real time without manual refresh.
- **User-scoped data:** All Firestore reads/writes are scoped by `FirebaseAuth.instance.currentUser.uid`, ensuring multi-tenancy and security at the path level.
- **Dual Firestore roots:** Core finance data uses `users/{uid}/...`; bill reminders use `artifacts/{appId}/users/{uid}/user_bills` for compatibility with a specific deployment model.

---

## 3. Data Flow Description

This section describes how data moves from the **User Interface** to the **Backend** (Firebase) and back, for the main use cases.

### 3.1 Authentication Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | LoginScreen (UI) | User → App | User enters email and password; optional “Remember me” and “Forgot password.” |
| 2 | _handleLogin() | App → Firebase Auth | `signInWithEmailAndPassword()`; on success, check `emailVerified`. |
| 3 | Firebase Auth | Backend | Validates credentials; returns UserCredential or throws FirebaseAuthException. |
| 4 | LoginScreen | App → Local | If “Remember me,” save email and flag in SharedPreferences. |
| 5 | LoginScreen | App → UI | Navigate to HomeScreen (pushReplacement). |

**Sign-up flow:** User enters name, email, password → `createUserWithEmailAndPassword()` → `sendEmailVerification()` → Firestore `users/{uid}.set({ fullName, email, uid })` → Dialog asking user to verify email → Navigate to LoginScreen.

### 3.2 Monthly Budget and Salary Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | HomeBody (UI) | User | User selects month/year; if no salary set, “Set Base Salary Now” is shown. |
| 2 | _showBaseSalaryDialog() (MainScaffold) | App → Firestore | Read `users/{uid}` for current baseSalary; show dialog. |
| 3 | User confirms amount | App → Firestore | Write `monthly_records/{year-month}.set({ baseSalaryAmount, totalSalary, month, year, lastUpdated }, merge)` and `users/{uid}.set({ baseSalary, lastUpdated }, merge)`. |
| 4 | _showExtraIncomeDialog() | App → Firestore | Increment `monthly_records/{docId}` totalSalary and extraIncome; add document to `transactions` with category `Bonus`. |
| 5 | Firestore snapshots | Backend → App | `monthly_records/{docId}.snapshots()` and `transactions.orderBy('timestamp', descending: true).snapshots()` in MainScaffold. |
| 6 | MainScaffold → HomeBody | App → UI | Pass streams and callbacks; HomeBody builds budget card, 50/30/20 progress bars, and recent transactions. |

### 3.3 Add Expense Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | AddExpenseScreen (UI) | User | User enters item name and amount; optional category/subcategory selection. |
| 2 | _detectCategory() | App (local) | Item string matched against _categoryKeywords; main category (Needs/Wants/Saving) is set. |
| 3 | _addExpense() / _checkAndSaveExpense() | App (local) | Validate amount and category; check 50/30/20 and total budget limits; show warnings if over limit. |
| 4 | _saveTransaction() | App → Firestore | `monthly_records/{docId}.set({ totalSalary, month, year, NeedsSpent/WantsSpent/SavingSpent increment, lastUpdated }, merge)`; then `transactions.add({ item, amount, category, subCategory, timestamp })`. |
| 5 | Firestore | Backend → App | MainScaffold and HomeBody listen to the same monthly_records and transactions streams; UI updates automatically. |
| 6 | AddExpenseScreen | App → UI | SnackBar and Navigator.pop(). |

### 3.4 Delete Transaction Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | HomeBody (UI) | User | User swipes to delete a transaction (Dismissible). |
| 2 | _deleteTransaction() (MainScaffold) | App → Firestore | Confirm dialog; then `transactions.doc(transactionId).delete()`. If category is Bonus/Salary, update monthly_records (totalSalary, extraIncome); else update corresponding *Spent field with increment(-amount). |
| 3 | Firestore snapshots | Backend → App | Streams emit new data; list and progress bars rebuild. |

### 3.5 Goals (Savings Goals) Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | GoalSettingScreen (UI) | User | User enters goal name, target amount, current saved amount, target date. |
| 2 | _saveGoal() | App → Firestore | `users/{uid}/saving_goals.add({ name, targetAmount, achievedAmount, targetDate, goalType, isCompleted, createdAt, monthlyContribution })`. |
| 3 | _getGoalsStream() | Firestore → App | `saving_goals.snapshots()`; list sorted locally (incomplete first, then by target date). |
| 4 | _updateGoalAmount() / _markAsComplete() / _deleteGoal() | App → Firestore | update(achievedAmount, isCompleted, completionDate, monthlyContribution) or delete(). |
| 5 | StreamBuilder | App → UI | Goal cards and progress bars update from stream. |

### 3.6 Recurring Bills and Notifications Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | BillSetupScreen (UI) | User | User enters bill name, amount, day of month, frequency (Monthly/Annually), reminder toggle. |
| 2 | _saveBill() | App → Firestore | `_getBillCollection().add({ name, amount, dayOfMonth, frequency, isActive, receiveReminders, lastPaidDate, createdAt })` (path: artifacts/{appId}/users/{uid}/user_bills). |
| 3 | BillSetupScreen | App → NotificationService | If receiveReminders, call `NotificationService.scheduleBillNotification(...)` with bill id, title, amount, frequency, dayOfMonth. |
| 4 | NotificationService | App → OS | `zonedSchedule` with matchDateTimeComponents for monthly reminder (e.g. day before due at 21:00). |
| 5 | _markAsPaid() | App → Firestore | Update bill lastPaidDate; cancel existing notification; optionally reschedule next cycle. |
| 6 | NotificationScreen | Firestore → App | Streams user_bills (and saving_goals) to show bill reminder cards and goal alerts. |

### 3.7 Profile and Edit Profile Flow

| Step | Location | Direction | Description |
|------|----------|-----------|-------------|
| 1 | ProfileScreen (UI) | User | Displays currentUser (photoURL, displayName, email) from Firebase Auth; Dark mode and Language from SettingsProvider. |
| 2 | EditProfileScreen | User | Change display name and/or profile photo (ImagePicker). |
| 3 | _updateProfile() | App → Firebase Auth | `user.updateDisplayName(newName)` and `user.reload()`. |
| 4 | _pickAndUploadImage() | App → Firebase Storage | Upload to `user_profiles/{uid}.jpg`; get download URL; `user.updatePhotoURL(photoUrl)`; reload. |
| 5 | EditProfileScreen | App → UI | Navigator.pop(true); ProfileScreen refreshes (e.g. reload user). |

### 3.8 Analysis and Category Transactions Flow

- **AnalysisScreen:** Reads `monthly_records/{docId}.snapshots()` for current month and a range query on `monthly_records` (document IDs between start and end month) for trend data. All processing (pie chart, line chart, insights) is done in the client; no additional backend calls.
- **CategoryTransactionsScreen:** Reads `monthly_records/{docId}/transactions` with `where('category', isEqualTo: categoryName)` and optional timestamp filters (Today, Last 7/30 Days, All). Data flows Firestore → StreamBuilder → ListView.

---

## 4. Function-wise Module Explanation

### 4.1 main.dart

| Function / Entry | Purpose |
|------------------|---------|
| `main()` | Ensures Flutter bindings, initializes Firebase, initializes NotificationService, checks getInitialNotification (launch from notification), wraps app in ChangeNotifierProvider&lt;SettingsProvider&gt; and runs MyApp. |
| `MyApp.build()` | Builds MaterialApp with debugShowCheckedModeBanner: false, title, themeMode and locale from SettingsProvider, supportedLocales (en, hi), localizationsDelegates, theme and darkTheme, and home: SplashScreen. |

### 4.2 splash_screen.dart

| Function | Purpose |
|----------|---------|
| `_navigateToNextScreen()` | After 4 seconds, reads FirebaseAuth.instance.currentUser; if non-null navigates to HomeScreen, else to WelcomeScreen (pushReplacement). |
| `build()` | Shows Lottie animation, “Finance Manager” text, and CircularProgressIndicator with theme-aware colors. |

### 4.3 welcome_screen.dart

| Function | Purpose |
|----------|---------|
| `build()` | Renders welcome image, tagline, “Sign Up” and “Log In” buttons; navigates to SignupScreen or LoginScreen on press. |

### 4.4 login_screen.dart

| Function | Purpose |
|----------|---------|
| `_loadRememberMeState()` | Loads rememberMe and email from SharedPreferences and pre-fills email if rememberMe is true. |
| `_showSnackBar(message, isError)` | Displays a floating SnackBar with icon and message. |
| `_handleLogin()` | Validates form; calls signInWithEmailAndPassword; checks emailVerified; on success saves remember me state and navigates to HomeScreen; on FirebaseAuthException shows localized error. |
| `_handleForgotPassword()` | Sends password reset email for _emailController.text; shows SnackBar. |
| `build()` | Builds form with email, password, remember me, “Forget Password,” and Login button; links to SignupScreen. |

### 4.5 signup_screen.dart

| Function | Purpose |
|----------|---------|
| `_validatePassword(value)` | Enforces length ≥ 8, first character uppercase, at least one digit and one special character. |
| `_showSnackBar(message, isError)` | Same pattern as login screen. |
| `_signup()` | Validates form; createUserWithEmailAndPassword; sendEmailVerification; writes users/{uid} with fullName, email, uid in Firestore; shows success SnackBar and _showVerificationDialog(). |
| `_showVerificationDialog()` | Shows non-dismissible dialog asking user to verify email; “Go back to Login Screen” navigates to LoginScreen. |
| `build()` | Form with full name, email, password (with visibility toggle), Sign Up button, and link to Login. |

### 4.6 home_screen.dart

| Function | Purpose |
|----------|---------|
| `build()` | Returns MainScaffold (no additional logic). |

### 4.7 main_scaffold.dart

| Function | Purpose |
|----------|---------|
| `_showBaseSalaryDialog()` | Fetches current baseSalary from users/{uid}; shows dialog for amount; on confirm writes monthly_records/{docId} (baseSalaryAmount, totalSalary, month, year, lastUpdated) and users/{uid} (baseSalary, lastUpdated) with merge. |
| `_showExtraIncomeDialog()` | Fetches current monthly_records; shows dialog; on confirm increments totalSalary and extraIncome, adds transaction with category Bonus, shows SnackBar. |
| `_deleteTransaction(transactionId, amount, category)` | Confirmation dialog; deletes transaction doc; if category Salary/Bonus decrements totalSalary (and extraIncome for Bonus), else decrements corresponding *Spent in monthly_records. |
| `_getMonthName(month)` | Returns English month name from 1–12. |
| `_getCategoryIcon(category, [subCategory])` | Returns IconData for Salary, Bonus, Needs, Wants, Saving. |
| `_setupDataStreams()` | Sets _monthlyDataStream = monthly_records/{docId}.snapshots() and _transactionsStream = transactions.orderBy('timestamp', descending: true).snapshots() for current user and selected month/year; clears if user is null. |
| `_initializeUserDate(User)` | Sets _userName, _userCreationDate, _selectedMonth/_selectedYear to now, then _setupDataStreams(). |
| `initState()` | Sets _selectedMonth/_selectedYear; subscribes to authStateChanges to update _currentUser and call _initializeUserDate or _setupDataStreams. |
| `build()` | If _currentUser is null shows loading message; else shows top bar (“My Salary,” profile icon), IndexedStack of _screens (HomeBody, AnalysisScreen, GoalSettingScreen, placeholder for Alerts, ProfileScreen), FAB opening AddExpenseScreen with current totals, and bottom navigation. |

### 4.8 home_body.dart

| Function | Purpose |
|----------|---------|
| `_buildProgressItem(context, title, spent, limit, color)` | Builds a progress row (title, spent/limit text, LinearProgressIndicator); on tap navigates to CategoryTransactionsScreen for that category and month/year. |
| `_buildMonthYearPicker(yearsList, monthsList)` | Two dropdowns for month and year calling onMonthChanged/onYearChanged and getMonthName. |
| `_buildSalaryPromptCard()` | Card shown when totalSalary is 0; “Set Base Salary Now” calls setBaseSalary. |
| `build()` | Uses StreamBuilder on monthlyDataStream; derives totalSalary, needs/wants/savings spent, limits (50/30/20); if salary missing shows prompt card else budget card; renders 50/30/20 progress items and StreamBuilder for transactions list (up to 5 items, Dismissible calling deleteTransaction). |

### 4.9 add_expense_screen.dart

| Function | Purpose |
|----------|---------|
| `_detectCategory(item)` | Normalizes item to lowercase and matches against _categoryKeywords to set _detectedCategory (Needs/Wants/Saving); resets _selectedSubCategory. |
| `_addExpense()` | Validates user, non-empty item/amount, positive amount; if category not detected opens _showCategorySelectionDialog; requires _selectedSubCategory; then _checkAndSaveExpense(amount, _detectedCategory, _selectedSubCategory). |
| `_checkAndSaveExpense(amount, category, subCategory)` | Computes category limit (50/30/20); if amount exceeds category limit (for Needs/Wants) or total remaining budget shows SnackBar and may return; else _saveTransaction. |
| `_saveTransaction(amount, category, subCategory)` | Writes monthly_records doc (merge with NeedsSpent/WantsSpent/SavingSpent increment) and transactions.add({ item, amount, category, subCategory, timestamp }); then SnackBar and pop. |
| `_showCategorySelectionDialog(amount)` | Dialog with radio for Needs/Wants/Saving; on confirm sets _detectedCategory and closes. |
| `build()` | Form: item name (onChanged → _detectCategory), amount, category display (tap to open dialog), subcategory dropdown, Add Expense button. |

### 4.10 analysis_screen.dart

| Function | Purpose |
|----------|---------|
| `_setupDataStreams()` | Sets _monthlyDataStream for selected month doc and _multiMonthTrendStream for monthly_records with document ID in range (last 6 months). |
| `_getMonthName(month)` | Short month name (Jan–Dec). |
| `_buildSection(...)` | Builds PieChartSectionData for pie chart. |
| `_buildTrendChartCard()` | StreamBuilder on _multiMonthTrendStream; builds line chart (FlSpot per month, total spent) with _getLineChartData. |
| `_getLineChartData(spots, titles, maxSpent)` | Returns LineChartData with grid, titles, and one LineChartBarData. |
| `_buildCategoryPieChartCard(...)` | Pie chart for budget overview (spent vs remaining per category) and center text (total budget, remaining). |
| `_getPieChartSections(...)` | Computes pie sections for Needs/Wants/Saving (spent and remaining) from limits and spent values. |
| `_buildPieChartLegend()` / `_buildLegendItemWithSpent(...)` | Legend for pie chart colors. |
| `_buildInsightCard(needsSpent, totalSalary)` | Shows text insight based on needs usage (over limit, near limit, or OK). |
| `_buildMonthlySummaryCard(...)` | Three columns: Needs, Wants, Saving with spent, target, remaining. |
| `_buildOverviewTab(...)` / `_buildTrendsTab(...)` | Tab contents: overview (pie + summary) vs trends (line chart + insight). |
| `build()` | Month/year dropdowns, TabBar (Overview & Budget, Trends & Insights), StreamBuilder on _monthlyDataStream feeding TabBarView. |

### 4.11 goal_setting_screen.dart

| Function | Purpose |
|----------|---------|
| `calculateMonthlyContribution(target, saved, targetDate)` | Returns (target - saved) / monthsRemaining using 30.44 days/month. |
| `_selectTargetDate()` | Opens date picker; updates _selectedTargetDate. |
| `_monthlyContributionEstimate` getter | Uses form values and _selectedTargetDate to compute and format monthly contribution text. |
| `_saveGoal()` | Validates form and user; adds document to users/{uid}/saving_goals with name, targetAmount, achievedAmount, targetDate, goalType, isCompleted, createdAt, monthlyContribution; _resetForm and SnackBar. |
| `_getGoalsStream()` | Returns saving_goals.snapshots(). |
| `_markAsComplete(id, isCompleted)` | Updates isCompleted, completionDate, and monthlyContribution (recomputed if restoring). |
| `_deleteGoal(id)` | Deletes goal document. |
| `_updateGoalAmount(id, name, achieved, targetAmount, targetDate)` | Dialog to add amount; updates achievedAmount (clamped), isCompleted if reached, completionDate, monthlyContribution. |
| `_resetForm()` | Clears controllers and resets _selectedTargetDate. |
| `_buildFormUI()` / `_buildGoalList()` | Form for new goal; StreamBuilder list of goal cards with progress bar, Add Funds, Mark Complete/Restore, Delete. |

### 4.12 profile_screen.dart

| Function | Purpose |
|----------|---------|
| `_buildProfileOption(...)` | Reusable row (icon, title, onTap, optional trailing) for settings entries. |
| `_goToEditProfileScreen(context, isDarkMode)` | Pushes EditProfileScreen; on return true, reloads currentUser and setState. |
| `build()` | Shows avatar (from photoURL), name, email, Edit Profile; Settings: Dark mode (Consumer&lt;SettingsProvider&gt; Switch), Language dropdown (SettingsProvider.setLanguage), Recurring Bill Setup (navigate to BillSetupScreen), Sign Out (signOut and pushAndRemoveUntil to WelcomeScreen). |

### 4.13 edit_profile_screen.dart

| Function | Purpose |
|----------|---------|
| `_pickAndUploadImage()` | Picks image via ImagePicker (gallery, quality 75); uploads to Firebase Storage user_profiles/{uid}.jpg; gets download URL; updates user.updatePhotoURL; user.reload(); SnackBar and pop(true). |
| `_updateProfile()` | Validates form; if name changed, user.updateDisplayName and user.reload(); pop(true) and SnackBar. |
| `build()` | Avatar (tap to upload), name field, read-only email, Save button. |

### 4.14 bill_setup_screen.dart

| Function | Purpose |
|----------|---------|
| `_getBillCollection()` | Returns artifacts/{appId}/users/{uid}/user_bills. |
| `_calculateNextDueDate(dayOfMonth, frequency, lastPaidTs)` | Computes next due date for Monthly or Annually; handles past dates. |
| `_saveBill()` | Validates form and _selectedDueDate; adds bill doc (name, amount, dayOfMonth, frequency, isActive, receiveReminders, lastPaidDate, createdAt); if receiveReminders calls NotificationService.scheduleBillNotification; _resetForm. |
| `_markAsPaid(billDocId, ...)` | Updates lastPaidDate; cancels notification; if receiveReminders reschedules via NotificationService.scheduleBillNotification. |
| `_deleteBill(billDocId)` | Deletes bill doc and cancels notification. |
| `_getBillsStream()` | user_bills.where('isActive', isEqualTo: true).snapshots(). |
| `_buildBillSetupForm()` / `_buildBillList()` | Form (name, amount, day 1–28, frequency, reminder switch, Save); StreamBuilder list of bill cards with next due, Mark as Paid, Delete. |

### 4.15 category_transactions_screen.dart

| Function | Purpose |
|----------|---------|
| `_getCategoryIcon(category)` | Maps category to IconData. |
| `_getFilteredTransactionsStream()` | Path: users/{uid}/monthly_records/{docId}/transactions; where category == widget.categoryName; applies timestamp filter (Today, Last 7 Days, Last 30 Days, All) then orderBy('timestamp', descending: true).snapshots(). |
| `build()` | Filter dropdown, StreamBuilder list of transaction cards (item, date, amount with +/-). |

### 4.16 notification_screen.dart

| Function | Purpose |
|----------|---------|
| `_getCollectionReference(collectionName)` | artifacts/{appId}/users/{uid}/{collectionName}. |
| `_getBillRemindersStream()` | user_bills where isActive == true, orderBy dayOfMonth, snapshots. |
| `_buildBillReminderCard(billDoc)` | Computes next due and remaining days; shows card only if within -7 to +30 days; status color and message (overdue, due today, days left). |
| `_getGoalWarningsStream()` | saving_goals where isCompleted == false, snapshots. |
| `_buildGoalWarningCard(goalDoc)` | Remaining amount, days to target, required monthly; filters out completed or very old goals; progress bar and status text. |
| `build()` | Two sections: Bill reminders (StreamBuilder) and Goal warnings (StreamBuilder). |

*Note:* In the current MainScaffold, the “Alerts” tab (index 3) shows a placeholder widget; the full NotificationScreen is implemented but can be wired by replacing that placeholder with NotificationScreen().

### 4.17 notification_service.dart

| Function | Purpose |
|----------|---------|
| `onDidReceiveNotificationResponse` | Callback when user taps notification; payload can be used for navigation (e.g. to bill). |
| `initialize()` | Initializes timezone, Android/iOS notification settings, and requestPermissions on iOS. |
| `scheduleBillNotification(id, title, amount, frequency, dayOfMonth, billId)` | Builds TZDateTime for dayOfMonth at 21:00; if in past, moves to next month; subtracts 1 day for “day before” reminder; uses zonedSchedule with matchDateTimeComponents: dayOfMonthAndTime for monthly repeat. |
| `cancelNotification(id)` | Cancels one scheduled notification. |
| `cancelAllNotifications()` | Cancels all. |
| `getInitialNotification()` | Returns launch details if app opened from notification. |

### 4.18 settings_provider.dart

| Function | Purpose |
|----------|---------|
| `toggleTheme(isDark)` | Sets _themeMode to dark or light; notifyListeners. |
| `_loadPreferredLocale()` | Reads languageCode from SharedPreferences; sets _locale (hi/EN/en or null); notifyListeners. |
| `setLanguage(languageCode)` | Sets _locale and writes/removes languageCode in SharedPreferences; notifyListeners. |

### 4.19 Localization and Theme

- **l10n:** app_en.arb / app_hi.arb and generated app_localizations*.dart provide localized strings; MaterialApp uses AppLocalizations.delegate and supportedLocales.
- **App Themes Definition.dart:** Defines lightTheme and darkTheme (ColorScheme, textTheme); the active theme in the app is defined in main.dart (theme/darkTheme) and themeMode comes from SettingsProvider.

---

## 5. Database Schema Description

The application uses **Google Cloud Firestore** (NoSQL). There are **no SQL queries**; data is accessed via Firestore collection/document paths and query methods. The schema below is the **logical structure** of collections and documents as used in the codebase.

### 5.1 Root Collections and Paths

Two root patterns are used:

1. **Primary (finance and user profile):** `users / {userId} / ...`
2. **Bills (and notification screen):** `artifacts / {appId} / users / {userId} / ...`

`userId` is `FirebaseAuth.instance.currentUser.uid`. `appId` is from environment or constant (e.g. `your_app_id` / `default-app-id`).

### 5.2 Collection: `users`

**Path:** `users/{userId}`

**Document fields (in code):**

| Field | Type | Description |
|-------|------|-------------|
| fullName | string | Set at signup (SignupScreen). |
| email | string | Set at signup. |
| uid | string | User ID (redundant with doc id). |
| baseSalary | number | Last set base salary; read in MainScaffold for “Set Base Salary” dialog. |
| lastUpdated | timestamp | Server timestamp when baseSalary or profile data was updated. |

**Subcollections:**

- `monthly_records` — see below.
- `saving_goals` — see below.

### 5.3 Subcollection: `users/{userId}/monthly_records`

**Document ID:** `{year}-{month}` (e.g. `2025-02`).

**Document fields:**

| Field | Type | Description |
|-------|------|-------------|
| baseSalaryAmount | number | Base salary for that month. |
| totalSalary | number | Base + extra income; used for 50/30/20. |
| extraIncome | number | Sum of bonus/extra income. |
| month | number | 1–12. |
| year | number | Full year. |
| NeedsSpent | number | Total expense in Needs (50%). |
| WantsSpent | number | Total expense in Wants (30%). |
| SavingSpent | number | Total allocated to Saving (20%). |
| lastUpdated | timestamp | Server timestamp. |

**Subcollection:** `transactions` — see below.

**Typical operations in code:**

- **Read:** `doc(docId).get()`, `doc(docId).snapshots()`.
- **Write:** `doc(docId).set({ ... }, SetOptions(merge: true))`, `doc(docId).update({ ... })` (e.g. increment *Spent or totalSalary/extraIncome).

### 5.4 Subcollection: `users/{userId}/monthly_records/{docId}/transactions`

**Document ID:** Auto-generated (e.g. `add()`).

**Document fields:**

| Field | Type | Description |
|-------|------|-------------|
| item | string | Description (e.g. “Groceries”, “Bonus / Extra Income (…)”). |
| amount | number | Amount. |
| category | string | One of: Needs, Wants, Saving, Salary, Bonus. |
| subCategory | string | Optional; used in AddExpenseScreen (e.g. “Groceries/Food”). |
| timestamp | timestamp | Server or client timestamp; used for ordering and filtering. |

**Typical operations in code:**

- **Read:** `orderBy('timestamp', descending: true).snapshots()`, or with `where('category', isEqualTo: ...)` and optional `where('timestamp', ...)` in CategoryTransactionsScreen.
- **Write:** `add({ item, amount, category, subCategory, timestamp })`.
- **Delete:** `doc(transactionId).delete()`.

### 5.5 Subcollection: `users/{userId}/saving_goals`

**Document ID:** Auto-generated.

**Document fields:**

| Field | Type | Description |
|-------|------|-------------|
| name | string | Goal name. |
| targetAmount | number | Target amount. |
| achievedAmount | number | Current saved amount. |
| targetDate | timestamp | Target date. |
| goalType | string | e.g. “Long-term”. |
| isCompleted | boolean | Whether goal is marked complete. |
| createdAt | timestamp | Creation time. |
| completionDate | timestamp | Set when isCompleted becomes true. |
| monthlyContribution | number | Estimated monthly contribution to meet target. |

**Typical operations in code:**

- **Read:** `snapshots()` (GoalSettingScreen, NotificationScreen with where isCompleted == false).
- **Write:** `add({ ... })`, `doc(id).update({ ... })`, `doc(id).delete()`.

### 5.6 Collection: `artifacts/{appId}/users/{userId}/user_bills`

**Document ID:** Auto-generated.

**Document fields:**

| Field | Type | Description |
|-------|------|-------------|
| name | string | Bill name. |
| amount | number | Bill amount. |
| dayOfMonth | number | 1–28. |
| frequency | string | “Monthly” or “Annually”. |
| isActive | boolean | Used to filter active bills. |
| receiveReminders | boolean | Whether to schedule local notifications. |
| lastPaidDate | timestamp | Last time “Mark as Paid” was used. |
| createdAt | timestamp | Creation time. |

**Typical operations in code:**

- **Read:** `where('isActive', isEqualTo: true).snapshots()` (BillSetupScreen); with `orderBy('dayOfMonth')` in NotificationScreen.
- **Write:** `add({ ... })`, `doc(id).update({ lastPaidDate })`, `doc(id).delete()`.

### 5.7 Query Patterns (Equivalent to “SQL-like” Operations)

| Intent | Firestore usage in code |
|--------|--------------------------|
| Single month data | `users/{uid}/monthly_records/{year-month}.snapshots()` or `.get()`. |
| Transactions for month, newest first | `monthly_records/{docId}/transactions.orderBy('timestamp', descending: true).snapshots()`. |
| Transactions by category | `transactions.where('category', isEqualTo: categoryName).orderBy('timestamp', descending: true).snapshots()` (with optional timestamp range). |
| Last 6 months for trend | `monthly_records.orderBy(FieldPath.documentId).where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId).where(FieldPath.documentId, isLessThanOrEqualTo: endDocId).snapshots()`. |
| Active bills | `user_bills.where('isActive', isEqualTo: true).snapshots()` (and optionally orderBy('dayOfMonth')). |
| Incomplete goals | `saving_goals.where('isCompleted', isEqualTo: false).snapshots()`. |

### 5.8 Other Storage

- **Firebase Authentication:** Stores user identity (email, uid, displayName, photoURL, emailVerified); no Firestore schema, but signup writes to `users/{uid}`.
- **Firebase Storage:** Path `user_profiles/{uid}.jpg` for profile photo; referenced only by Auth photoURL.
- **SharedPreferences:** Keys `rememberMe`, `email` (login), `languageCode` (SettingsProvider); not part of Firestore.

---

## 6. References

- Flutter: https://flutter.dev  
- Firebase for Flutter: https://firebase.google.com/docs/flutter/setup  
- Cloud Firestore: https://firebase.google.com/docs/firestore  
- Firebase Authentication: https://firebase.google.com/docs/auth  
- Provider package: https://pub.dev/packages/provider  
- flutter_local_notifications: https://pub.dev/packages/flutter_local_notifications  

---

*End of Report*
