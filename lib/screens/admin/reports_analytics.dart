import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';


class ReportsAnalyticsPage extends StatefulWidget {
  const ReportsAnalyticsPage({super.key});

  @override
  State<ReportsAnalyticsPage> createState() => _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends State<ReportsAnalyticsPage> {
  int approved = 0;
  int pending = 0;
  int rejected = 0;
  int homeowners = 0;
  int students = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final firestore = FirebaseFirestore.instance;

    final approvedSnap = await firestore
        .collection('houses')
        .where('status', isEqualTo: 'approved')
        .get();
    final pendingSnap = await firestore
        .collection('houses')
        .where('status', isEqualTo: 'pending')
        .get();
    final rejectedSnap = await firestore
        .collection('houses')
        .where('status', isEqualTo: 'rejected')
        .get();
    final homeownersSnap = await firestore.collection('homeowners').get();
    final studentsSnap = await firestore.collection('students').get();

    setState(() {
      approved = approvedSnap.size;
      pending = pendingSnap.size;
      rejected = rejectedSnap.size;
      homeowners = homeownersSnap.size;
      students = studentsSnap.size;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    "Reports & Analytics",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // ===== Bar Chart: House Status =====
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "House Status Overview",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 250),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: ([approved, pending, rejected].reduce((a, b) => a > b ? a : b) == 0)
                                    ? 1
                                    : [approved, pending, rejected].reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                    toY: approved.toDouble(),
                                    color: theme.colorScheme.primary)
                              ],
                              showingTooltipIndicators: [0],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                    toY: pending.toDouble(),
                                    color: Colors.orange)
                              ],
                              showingTooltipIndicators: [0],
                            ),
                            BarChartGroupData(
                              x: 2,
                              barRods: [
                                BarChartRodData(
                                    toY: rejected.toDouble(),
                                    color: Colors.red)
                              ],
                              showingTooltipIndicators: [0],
                            ),
                          ],
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  const labels = ['Approved', 'Pending', 'Rejected'];
                                  final index = value.toInt();
                                  final text = (index >= 0 && index < labels.length) ? labels[index] : '';
                                  return Text(text);
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ===== Pie Chart: Users Overview =====
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "User Type Distribution",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: homeowners.toDouble(),
                                    title: 'Homeowners',
                                    color: Colors.purple,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: students.toDouble(),
                                    title: 'Students',
                                    color: Colors.purpleAccent,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                                sectionsSpace: 4,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
