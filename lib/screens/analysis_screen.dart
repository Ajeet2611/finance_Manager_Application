import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalysisScreen extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final Function(int) onMonthChanged;
  final Function(int) onYearChanged;

  const AnalysisScreen({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  Stream<DocumentSnapshot>? _monthlyDataStream;
  Stream<QuerySnapshot>? _multiMonthTrendStream;

  // --- 🎨 Color Palette for Pie Chart (Colors are fine, used as constants) ---
  static const Color needsColor = Color(0xFF87CEEB);
  static const Color needsSpentColor = Color(0xFF1E90FF);

  static const Color wantsColor = Color(0xFFFFD700);
  static const Color wantsSpentColor = Color(0xFFFFA500);

  static const Color savingColor = Color(0xFF32CD32);
  static const Color savingSpentColor = Color(0xFF008000);
  // ----------------------------------------

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupDataStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMonth != oldWidget.selectedMonth ||
        widget.selectedYear != oldWidget.selectedYear) {
      _setupDataStreams();
    }
  }

  void _setupDataStreams() {
    final user = _auth.currentUser;
    if (user != null) {
      final selectedDate = DateTime(widget.selectedYear, widget.selectedMonth);

      final docId = '${widget.selectedYear}-${widget.selectedMonth.toString().padLeft(2, '0')}';
      _monthlyDataStream = _firestore
          .collection('users').doc(user.uid).collection('monthly_records').doc(docId).snapshots();

      final lastSixMonths = selectedDate.subtract(const Duration(days: 180));

      final startDocId = '${lastSixMonths.year}-${lastSixMonths.month.toString().padLeft(2, '0')}';
      final endDocId = docId;

      _multiMonthTrendStream = _firestore
          .collection('users').doc(user.uid).collection('monthly_records')
          .orderBy(FieldPath.documentId, descending: false)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .snapshots();
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month];
  }

  // Pie Chart Section Helper
  PieChartSectionData _buildSection(double percentageValue, Color color, String title) {
    if (percentageValue <= 0) return PieChartSectionData(value: 0);

    // 💡 Fix: Dynamic text color for Pie Chart section titles
    final isDarkBackground = Theme.of(context).brightness == Brightness.dark;

    Color titleColor;
    if (color == needsColor || color == wantsColor || color == savingColor) {
      // Light colors (Remaining Budget) should have dark text
      titleColor = isDarkBackground ? Colors.black87 : Colors.black87;
    } else {
      // Dark colors (Spent Budget) should have light text
      titleColor = Colors.white;
    }

    return PieChartSectionData(
      color: color,
      value: percentageValue,
      title: '${percentageValue.toStringAsFixed(1)}%',
      radius: 60,
      titleStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: titleColor,
      ),
      badgePositionPercentageOffset: 1.1,
    );
  }

  // Trend Chart Logic
  Widget _buildTrendChartCard() {
    // 💡 Fix: Card color is removed to use default theme color
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 Fix: Use Theme-aware Text Color
            Text('📈 Spending Trend (Last 6 Months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium!.color)),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _multiMonthTrendStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // 💡 Fix: Use Theme-aware Text Color
                  return SizedBox(height: 200, child: Center(child: Text('No data for the last 6 months.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall!.color))));
                }

                final docs = snapshot.data!.docs;
                final List<FlSpot> trendSpots = [];
                final List<String> bottomTitles = [];
                double maxSpent = 0;

                for (int i = 0; i < docs.length; i++) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final needs = (data['NeedsSpent'] ?? 0.0).toDouble();
                  final wants = (data['WantsSpent'] ?? 0.0).toDouble();
                  final savings = (data['SavingSpent'] ?? 0.0).toDouble();
                  final totalSpent = needs + wants + savings;

                  if (totalSpent > maxSpent) {
                    maxSpent = totalSpent;
                  }

                  final monthNum = int.parse(docs[i].id.split('-')[1]);
                  bottomTitles.add(_getMonthName(monthNum).substring(0, 3));
                  trendSpots.add(FlSpot(i.toDouble(), totalSpent));
                }

                return SizedBox(
                  height: 200,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 18.0, top: 18.0),
                    child: LineChart(_getLineChartData(trendSpots, bottomTitles, maxSpent)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _getLineChartData(List<FlSpot> spots, List<String> titles, double maxSpent) {
    final intervalY = (maxSpent / 3).ceilToDouble();
    final reservedSizeX = maxSpent > 100000 ? 55.0 : 45.0;

    // 💡 Fix: Get Theme colors for chart elements
    final axisColor = Theme.of(context).textTheme.bodySmall!.color ?? Colors.grey;
    final borderColor = Theme.of(context).dividerColor;

    return LineChartData(
      minY: 0,
      maxY: maxSpent * 1.15,
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < titles.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  // 💡 Fix: Use Theme color
                  child: Text(titles[value.toInt()], style: TextStyle(fontSize: 12, color: axisColor)),
                );
              }
              return const SizedBox();
            },
            interval: 1,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox();
              if (value % intervalY.toInt() == 0 || value.toInt() == maxSpent.toInt()) {
                return Text(
                  NumberFormat.compact().format(value),
                  // 💡 Fix: Use Theme color
                  style: TextStyle(fontSize: 10, color: axisColor),
                );
              }
              return const SizedBox();
            },
            reservedSize: reservedSizeX,
          ),
        ),
      ),
      // 💡 Fix: Use Theme color for border
      borderData: FlBorderData(show: true, border: Border.all(color: borderColor, width: 0.5)),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFFFFD700),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: const Color(0xFFFFD700).withOpacity(0.3)),
        ),
      ],
    );
  }


  // 2. Category Distribution (Pie Chart)
  Widget _buildCategoryPieChartCard(double needsSpent, double wantsSpent, double savingsSpent, double totalSalary) {
    final totalSpent = needsSpent + wantsSpent + savingsSpent;
    final remainingBalance = totalSalary - totalSpent;

    // 💡 Fix: Use Theme-aware Text Color
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium!.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall!.color;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // 💡 Fix: Card color is removed to use default theme color
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 Fix: Use Theme-aware Text Color
            Text('💰 Budget Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
            const SizedBox(height: 60),

            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Pie Chart
                  PieChart(
                    PieChartData(
                      sections: _getPieChartSections(needsSpent, wantsSpent, savingsSpent, totalSalary),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {}),
                    ),
                  ),

                  // 2. Center Content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 💡 Fix: Use Theme-aware Text Color
                      Text('Total Budget', style: TextStyle(fontSize: 10, color: secondaryTextColor)),
                      // 💡 Fix: Use Theme-aware Text Color
                      Text('₹${totalSalary.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                      const SizedBox(height: 4),
                      Text(
                        'Remaining: \n  ₹ ${remainingBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: remainingBalance >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Pie Chart Legend - Now Detailed
            _buildPieChartLegend(),
          ],
        ),
      ),
    );
  }

  // Pie Chart Sections (Logic is fine)
  List<PieChartSectionData> _getPieChartSections(double needsSpent, double wantsSpent, double savingsSpent, double totalSalary) {
    if (totalSalary <= 0) return [PieChartSectionData(value: 100, color: Colors.grey, title: '0%', radius: 60)];
    // ... logic remains unchanged ...
    final double needsLimit = totalSalary * 0.5;
    final double wantsLimit = totalSalary * 0.3;
    final double savingLimit = totalSalary * 0.2;

    List<PieChartSectionData> sections = [];

    // --- NEEDS (50%) ---
    final double needsSpentInLimit = needsSpent > needsLimit ? needsLimit : needsSpent;
    if (needsSpentInLimit > 0) {
      sections.add(_buildSection((needsSpentInLimit / totalSalary) * 100, needsSpentColor, 'Needs Spent'));
    }
    final double needsRemaining = (needsLimit - needsSpent > 0) ? needsLimit - needsSpent : 0;
    if (needsRemaining > 0) {
      sections.add(_buildSection((needsRemaining / totalSalary) * 100, needsColor, 'Needs Rem.'));
    }

    // --- WANTS (30%) ---
    final double wantsSpentInLimit = wantsSpent > wantsLimit ? wantsLimit : wantsSpent;
    if (wantsSpentInLimit > 0) {
      sections.add(_buildSection((wantsSpentInLimit / totalSalary) * 100, wantsSpentColor, 'Wants Spent'));
    }
    final double wantsRemaining = (wantsLimit - wantsSpent > 0) ? wantsLimit - wantsSpent : 0;
    if (wantsRemaining > 0) {
      sections.add(_buildSection((wantsRemaining / totalSalary) * 100, wantsColor, 'Wants Rem.'));
    }

    // --- SAVING (20%) ---
    if (savingsSpent > 0) {
      sections.add(_buildSection((savingsSpent / totalSalary) * 100, savingSpentColor, 'Saving Ach.'));
    }
    final double savingDeficit = (savingLimit - savingsSpent > 0) ? savingLimit - savingsSpent : 0;
    if (savingDeficit > 0) {
      sections.add(_buildSection((savingDeficit / totalSalary) * 100, savingColor, 'Saving Def.'));
    }

    return sections;
  }

  // Pie Chart Legend
  Widget _buildPieChartLegend() {
    // 💡 Fix: Get Theme color for legend text
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium!.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall!.color;

    // 💡 Fix: Adjust color for spent/target explanation icons
    final spentIconColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
    final targetIconColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title for the Legend
        Center(
          // 💡 Fix: Use Theme-aware Text Color
          child: Text(
            'Color Legend',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: primaryTextColor),
          ),
        ),
        const SizedBox(height: 30),

        // Row 1: Needs and Wants
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItemWithSpent('Needs (50%)', needsColor, needsSpentColor),
            _buildLegendItemWithSpent('Wants (30%)', wantsColor, wantsSpentColor),
          ],
        ),
        const SizedBox(height: 15),

        // Row 2: Saving and Explanation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItemWithSpent('Saving (20%)', savingColor, savingSpentColor),
            const SizedBox(width: 40),
            // Short Explanation (Dark vs Light)
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 💡 Fix: Use Theme-aware icon color
                      Icon(Icons.circle, size: 8, color: spentIconColor),
                      const SizedBox(width: 4),
                      // 💡 Fix: Use Theme-aware Text Color
                      Text('Spent (Dark)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: primaryTextColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 💡 Fix: Use Theme-aware icon color
                      Icon(Icons.circle, size: 8, color: targetIconColor),
                      const SizedBox(width: 4),
                      // 💡 Fix: Use Theme-aware Text Color
                      Text('Target (Light)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: primaryTextColor)),
                    ],
                  )
                ]
            )
          ],
        ),
      ],
    );
  }

  // Helper for building detailed legend items
  Widget _buildLegendItemWithSpent(String title, Color remainingColor, Color spentColor) {
    // 💡 Fix: Get Theme color for legend item text
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium!.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 💡 Fix: Use Theme-aware Text Color
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: remainingColor,
                  borderRadius: BorderRadius.circular(3)
              ),
            ),
            const SizedBox(width: 4),
            // 💡 Fix: Use Theme-aware Text Color
            Text('Target', style: TextStyle(fontSize: 12, color: primaryTextColor)),
            const SizedBox(width: 8),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: spentColor,
                  borderRadius: BorderRadius.circular(3)
              ),
            ),
            const SizedBox(width: 4),
            // 💡 Fix: Use Theme-aware Text Color
            Text('Spent', style: TextStyle(fontSize: 12, color: primaryTextColor)),
          ],
        ),
      ],
    );
  }

  // 3. Key Insights
  Widget _buildInsightCard(double needsSpent, double totalSalary) {
    final needsLimit = totalSalary * 0.5;
    final needsUsage = needsLimit > 0 ? (needsSpent / needsLimit) : 0.0;

    // 💡 Fix: Use Theme-aware Text Color
    final insightTextColor = Theme.of(context).textTheme.bodyMedium!.color;

    String dynamicInsight;
    String statusEmoji;

    if (totalSalary <= 0) {
      dynamicInsight = 'Please set your Monthly Budget (Salary) to see analysis.';
      statusEmoji = 'ℹ️';
    } else if (needsUsage >= 1.0) {
      dynamicInsight = 'You have exceeded the \'Needs\' budget limit! Review your mandatory expenses.';
      statusEmoji = '🚨';
    } else if (needsUsage >= 0.90) {
      dynamicInsight = 'You have used ${(needsUsage * 100).toStringAsFixed(0)}% of your \'Needs\' budget.';
      statusEmoji = '⚠️';
    } else {
      dynamicInsight = 'Your expenses are under control. Keep up the good work!';
      statusEmoji = '✅';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // 💡 Fix: Use Theme Surface color and opacity to blend well
      color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFFFFD700)),
                const SizedBox(width: 8),
                // 💡 Fix: Use Theme-aware Text Color
                Text('💡 Key Insights & Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: insightTextColor)),
              ],
            ),
            const SizedBox(height: 12),
            _buildInsightPoint('$statusEmoji $dynamicInsight'),
            _buildInsightPoint('🎯 Set a new Monthly Goal.'),
            _buildInsightPoint('🛑 Avoid overspending on WANTS this month.'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightPoint(String text) {
    // 💡 Fix: Use Theme-aware Text Color
    final insightTextColor = Theme.of(context).textTheme.bodyMedium!.color;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💡 Fix: Use Theme-aware Text Color
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: insightTextColor))),
        ],
      ),
    );
  }

  // 4. Monthly Expense Summary (Increased Vertical Spacing)
  Widget _buildMonthlySummaryCard(double needsSpent, double wantsSpent, double savingsSpent, double totalSalary) {

    // Limits based on 50/30/20 rule
    final needsLimit = totalSalary * 0.5;
    final wantsLimit = totalSalary * 0.3;
    final savingLimit = totalSalary * 0.2;

    // 💡 Fix: Use Theme-aware Text Color
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium!.color;
    final dividerColor = Theme.of(context).dividerColor;


    Widget buildColumn({
      required String title,
      required double spent,
      required double limit,
      required Color spentColor,
      required Color limitColor
    }) {

      final remaining = limit - spent;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            children: [
              // 💡 Fix: Use Theme-aware Text Color
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryTextColor)),
              const SizedBox(height: 8),
              // Spent Amount (Main focus)
              Text(
                '₹${spent.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: spentColor,
                ),
              ),
              const SizedBox(height: 6),
              // Limit/Target
              Text(
                'Target: ₹${limit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: limitColor, // Limit colors are constants, should be fine
                ),
              ),
              const SizedBox(height: 4),
              // Status/Remaining
              Text(
                remaining >= 0 ? 'Rem: ₹${remaining.toStringAsFixed(0)}' : 'Extra: ₹${(-remaining).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: remaining >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // 💡 Fix: Card color is removed to use default theme color
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 Fix: Use Theme-aware Text Color
            Text('💸 Monthly Expense Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                buildColumn(
                  title: 'Needs (50%)',
                  spent: needsSpent,
                  limit: needsLimit,
                  spentColor: needsSpentColor,
                  limitColor: needsColor,
                ),
                // 💡 Fix: Use Theme color for divider
                Container(width: 1, height: 100, color: dividerColor.withOpacity(0.5)),
                buildColumn(
                  title: 'Wants (30%)',
                  spent: wantsSpent,
                  limit: wantsLimit,
                  spentColor: wantsSpentColor,
                  limitColor: wantsColor,
                ),
                // 💡 Fix: Use Theme color for divider
                Container(width: 1, height: 100, color: dividerColor.withOpacity(0.5)),
                buildColumn(
                  title: 'Saving (20%)',
                  spent: savingsSpent,
                  limit: savingLimit,
                  spentColor: savingSpentColor,
                  limitColor: savingColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 🏗️ Tab Content 1 & 2 remain unchanged (they use the updated widgets) ---
  Widget _buildOverviewTab(double needsSpent, double wantsSpent, double savingsSpent, double totalSalary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoryPieChartCard(needsSpent, wantsSpent, savingsSpent, totalSalary),
          const SizedBox(height: 20),
          _buildMonthlySummaryCard(needsSpent, wantsSpent, savingsSpent, totalSalary),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(double needsSpent, double totalSalary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTrendChartCard(),
          const SizedBox(height: 16),
          _buildInsightCard(needsSpent, totalSalary),
        ],
      ),
    );
  }

  // --- 🏗️ Main Build Method ---

  @override
  Widget build(BuildContext context) {
    // 💡 Fix: Get Theme colors for dropdown items
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium!.color;

    return Column(
      children: [
        // Top Bar: Month/Year Pickers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<int>(
                value: widget.selectedYear,
                iconEnabledColor: primaryTextColor, // 💡 Fix: Set icon color
                items: List.generate(10, (index) => DateTime.now().year - index)
                    .map((year) => DropdownMenuItem(
                  value: year,
                  // 💡 Fix: Use Theme-aware Text Color
                  child: Text(year.toString(), style: TextStyle(color: primaryTextColor)),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onYearChanged(value);
                  }
                },
              ),
              DropdownButton<int>(
                value: widget.selectedMonth,
                iconEnabledColor: primaryTextColor, // 💡 Fix: Set icon color
                items: List.generate(12, (index) => index + 1)
                    .map((month) => DropdownMenuItem(
                  value: month,
                  // 💡 Fix: Use Theme-aware Text Color
                  child: Text(_getMonthName(month), style: TextStyle(color: primaryTextColor)),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onMonthChanged(value);
                  }
                },
              ),
            ],
          ),
        ),

        // Tab Bar
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          // 💡 Fix: Unselected label color should be theme aware (e.g., secondary text color)
          unselectedLabelColor: Theme.of(context).textTheme.bodySmall!.color,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Overview & Budget'),
            Tab(text: 'Trends & Insights'),
          ],
        ),

        // Tab Content
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _monthlyDataStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // 💡 Fix: Use Theme-aware Text Color
                return Center(child: Text('Failed to load data: ${snapshot.error}', style: TextStyle(color: primaryTextColor)));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                // 💡 Fix: Use Theme-aware Text Color
                return Center(child: Text('No data found for this month.', style: TextStyle(color: primaryTextColor)));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final totalSalary = (data['totalSalary'] ?? 0.0).toDouble();
              final needsSpent = (data['NeedsSpent'] ?? 0.0).toDouble();
              final wantsSpent = (data['WantsSpent'] ?? 0.0).toDouble();
              final savingsSpent = (data['SavingSpent'] ?? 0.0).toDouble();

              if (totalSalary <= 0) {
                return Center(child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  // 💡 Fix: Use Theme-aware Text Color
                  child: Text('Please set the monthly salary (budget) to see the analysis.', textAlign: TextAlign.center, style: TextStyle(color: primaryTextColor)),
                ));
              }

              // Display TabView with data
              return TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Overview and Summary
                  _buildOverviewTab(needsSpent, wantsSpent, savingsSpent, totalSalary),

                  // Tab 2: Trends and Insights
                  _buildTrendsTab(needsSpent, totalSalary),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}