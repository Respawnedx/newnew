import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:shared_preferences/shared_preferences.dart'; // For shared preferences

class IndberetPage extends StatefulWidget {
  final List<String> eventLog; // Accepting event log data

  const IndberetPage({super.key, required this.eventLog});

  @override
  _IndberetPageState createState() => _IndberetPageState();
}

class _IndberetPageState extends State<IndberetPage> {
  bool _isEditing = false;

  // Map to hold working days for each month
  Map<String, int> _workingDaysByMonth = {
    "Januar": 0,
    "Februar": 0,
    "Marts": 0,
    "April": 0,
    "Maj": 0,
    "Juni": 0,
    "Juli": 0,
    "August": 0,
    "September": 0,
    "Oktober": 0,
    "November": 0,
    "December": 0,
  };

  @override
  void initState() {
    super.initState();
    _loadWorkingDays(); // Load saved working days from shared preferences
    _calculateWorkingDays(); // Calculate working days from the event log
  }

  void _calculateWorkingDays() {
    // Reset the working days count
    _workingDaysByMonth.updateAll((key, value) => 0);

    for (var event in widget.eventLog) {
      if (event.startsWith("Entry Data") || event.startsWith("Exit Data")) {
        // Extract date from event message
        String datePart = event.split(" at ")[1];
        DateTime dateTime = DateFormat('yyyy-MM-ddTHH:mm:ss').parse(datePart); // Ensure the correct format is used

        String month = DateFormat('MMMM').format(dateTime); // Full month name
        // Increment working days for the month
        if (_workingDaysByMonth.containsKey(month)) {
          _workingDaysByMonth[month] = _workingDaysByMonth[month]! + 1;
        }
      }
    }
  }

  Future<void> _loadWorkingDays() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workingDaysByMonth.forEach((month, _) {
        _workingDaysByMonth[month] = prefs.getInt(month) ?? 0; // Load saved working days
      });
    });
  }

  Future<void> _saveWorkingDays() async {
    final prefs = await SharedPreferences.getInstance();
    for (var month in _workingDaysByMonth.keys) {
      await prefs.setInt(month, _workingDaysByMonth[month]!); // Save working days
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Indberet'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _saveWorkingDays(); // Save the working days when exiting edit mode
                }
                _isEditing = !_isEditing; // Toggle edit mode
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _calculateWorkingDays(); // Refresh working days based on the latest event log
                  });
                },
                child: Text('Generate Mock Data for Working Days'),
              ),
            ),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _workingDaysByMonth.length,
              itemBuilder: (context, index) {
                String month = _workingDaysByMonth.keys.elementAt(index);
                int workingDays = _workingDaysByMonth[month]!;

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(month, style: TextStyle(fontSize: 16)),
                      if (_isEditing) ...[
                        Container(
                          width: 50,
                          child: TextField(
                            controller: TextEditingController(text: workingDays.toString()),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              // Update the working days in the map
                              if (int.tryParse(value) != null) {
                                _workingDaysByMonth[month] = int.parse(value);
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        Text(workingDays.toString(), style: TextStyle(fontSize: 16)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
