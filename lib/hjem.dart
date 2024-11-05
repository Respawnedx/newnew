import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importing for TextInputFormatter
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'indberet.dart';

class HjemPage extends StatefulWidget {
  const HjemPage({super.key});

  @override
  _HjemPageState createState() => _HjemPageState();
}

class _HjemPageState extends State<HjemPage> {
  final Location _location = Location();
  final LatLng _zoneCenter = LatLng(37.7749, -122.4194);
  final double _zoneRadius = 150.0;
  bool _isInZone = false;
  DateTime? _entryTime;
  List<String> _eventLog = [];
  int _estimatedTransitionTime = 5; // Default transition time in minutes
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadTransitionTime();
    _loadEventLog();
    _startTracking();
  }

  Future<void> _loadTransitionTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _estimatedTransitionTime = prefs.getInt('estimatedTransitionTime') ?? 5;
    });
  }

  Future<void> _saveTransitionTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('estimatedTransitionTime', _estimatedTransitionTime);
  }

  void _startTracking() async {
    bool _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) return;
    }

    PermissionStatus _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }

    _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
      LatLng userPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      _checkZoneEntryExit(userPosition);
    });
  }

  void _checkZoneEntryExit(LatLng userPosition) {
    final distance = Distance().as(LengthUnit.Meter, userPosition, _zoneCenter);

    if (distance <= _zoneRadius && !_isInZone) {
      _isInZone = true;
      _entryTime = DateTime.now();
      _logEvent("Entry Data: Entered Zone at ${_entryTime!.toUtc().toIso8601String()}");
    } else if (distance > _zoneRadius && _isInZone) {
      _isInZone = false;
      DateTime exitTime = DateTime.now();
      _logEvent("Exit Data: Exited Zone at ${exitTime.toUtc().toIso8601String()}");

      if (_entryTime != null) {
        final duration = exitTime.difference(_entryTime!).inMinutes - _estimatedTransitionTime;
        _logEvent("Time spent in zone: $duration minutes (adjusted)");
        _entryTime = null;
      }
    }
  }

  void _logEvent(String message) {
    setState(() {
      _eventLog.insert(0, message); 
      if (_eventLog.length > 10) {
        _eventLog.removeLast(); 
      }
    });
    _saveEventLog();

    // Navigate to IndberetPage when an event is logged
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => IndberetPage(eventLog: _eventLog),
      ),
    );
  }

  Future<void> _saveEventLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('eventLog', _eventLog);
  }

  Future<void> _loadEventLog() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _eventLog = prefs.getStringList('eventLog') ?? [];
    });
  }

  void _generateMockData() {
    setState(() {
      for (int i = 1; i <= 5; i++) {
        _eventLog.insert(0, "Mock Event $i at ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().subtract(Duration(minutes: i)))}");
      }
    });
    _saveEventLog();
  }

  void _clearEventLog() {
    setState(() {
      _eventLog.clear(); 
    });
    _saveEventLog(); 
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Color _getEventColor(String message) {
    if (message.startsWith("Entry Data")) {
      return Colors.cyan; 
    } else if (message.startsWith("Exit Data")) {
      return Colors.redAccent; 
    }
    return Colors.black; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Event Logger')),
      body: SingleChildScrollView( 
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Removed the text field for input and only kept the slider
                  Slider(
                    value: _estimatedTransitionTime.toDouble(),
                    min: 0,
                    max: 60,
                    divisions: 60,
                    label: _estimatedTransitionTime.toString(),
                    onChanged: (value) {
                      setState(() {
                        _estimatedTransitionTime = value.toInt();
                      });
                      _saveTransitionTime(); 
                    },
                  ),
                  Text('Selected Time: $_estimatedTransitionTime minutes'),
                  ElevatedButton(
                    onPressed: _generateMockData,
                    child: Text('Generate Mock Data'),
                  ),
                  ElevatedButton(
                    onPressed: _clearEventLog,
                    child: Text('Clear Event Log'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _eventLog.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  elevation: 4, 
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        _eventLog[index],
                        textAlign: TextAlign.center, 
                        style: TextStyle(fontSize: 16, color: _getEventColor(_eventLog[index])),
                      ),
                    ),
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
