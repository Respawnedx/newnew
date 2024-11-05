import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:shared_preferences/shared_preferences.dart'; // For shared preferences

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30)); // Default start date (30 days ago)
  DateTime _endDate = DateTime.now(); // Default end date (today)
  DateTime _normalPayPeriodStart = DateTime.now().subtract(Duration(days: 15)); // Default pay period start
  DateTime _normalPayPeriodEnd = DateTime.now(); // Default pay period end
  int _totalHoursWorked = 0; // Total working hours calculated

  @override
  void initState() {
    super.initState();
    _calculateWorkingHours(); // Calculate the working hours initially
  }

  // Function to calculate total working hours based on logged events
  void _calculateWorkingHours() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? eventLog = prefs.getStringList('eventLog') ?? [];

    int hoursWorked = 0;

    for (var event in eventLog) {
      if (event.startsWith("Entry Data") || event.startsWith("Exit Data")) {
        String datePart = event.split(" at ")[1];
        DateTime eventDateTime = DateFormat('yyyy-MM-ddTHH:mm:ss').parse(datePart);

        if (eventDateTime.isAfter(_startDate) && eventDateTime.isBefore(_endDate)) {
          // Assuming each entry and exit represent a full working hour (this can be adjusted as needed)
          hoursWorked += 1; // Add working hours accordingly
        }
      }
    }

    setState(() {
      _totalHoursWorked = hoursWorked; // Update the state with calculated hours
    });
  }

  // Function to show date picker for start date
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _calculateWorkingHours(); // Recalculate hours whenever the date is changed
    }
  }

  // Function to show date picker for end date
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _calculateWorkingHours(); // Recalculate hours whenever the date is changed
    }
  }

  // Function to show date picker for normal pay period start date
  Future<void> _selectNormalPayPeriodStart(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _normalPayPeriodStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _normalPayPeriodStart) {
      setState(() {
        _normalPayPeriodStart = picked;
      });
    }
  }

  // Function to show date picker for normal pay period end date
  Future<void> _selectNormalPayPeriodEnd(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _normalPayPeriodEnd,
      firstDate: _normalPayPeriodStart,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _normalPayPeriodEnd) {
      setState(() {
        _normalPayPeriodEnd = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Normal Pay Period selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Normal Pay Period Start: ${DateFormat('yyyy-MM-dd').format(_normalPayPeriodStart)}"),
                      ElevatedButton(
                        onPressed: () => _selectNormalPayPeriodStart(context),
                        child: Text('Select Start Date'),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Normal Pay Period End: ${DateFormat('yyyy-MM-dd').format(_normalPayPeriodEnd)}"),
                      ElevatedButton(
                        onPressed: () => _selectNormalPayPeriodEnd(context),
                        child: Text('Select End Date'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Pay period status box
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.yellow[100],
              child: Text(
                _getPayPeriodStatus(),
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Start Date: ${DateFormat('yyyy-MM-dd').format(_startDate)}"),
                      ElevatedButton(
                        onPressed: () => _selectStartDate(context),
                        child: Text('Select Start Date'),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("End Date: ${DateFormat('yyyy-MM-dd').format(_endDate)}"),
                      ElevatedButton(
                        onPressed: () => _selectEndDate(context),
                        child: Text('Select End Date'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text("Total Working Hours: $_totalHoursWorked", style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            // Optional: Add a table or other display for detailed hour logging if needed
          ],
        ),
      ),
    );
  }

  // Function to determine if the selected date range is the current pay period
  String _getPayPeriodStatus() {
    if (_startDate.isBefore(_normalPayPeriodStart) && _endDate.isAfter(_normalPayPeriodEnd)) {
      return 'You are viewing the correct pay period.';
    } else {
      return 'You are viewing an incorrect pay period.';
    }
  }
}
