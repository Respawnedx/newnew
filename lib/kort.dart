import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class KortPage extends StatefulWidget {
  const KortPage({super.key});

  @override
  KortPageState createState() => KortPageState();
}

class KortPageState extends State<KortPage> {
  final MapController _mapController = MapController();
  final loc.Location _location = loc.Location();
  final FocusNode _searchFocusNode = FocusNode();
  LatLng? _userPosition;
  LatLng? _searchedPosition;
  double _zoomLevel = 15.0;
  bool _locationLoaded = false;
  double _radius = 150.0; // Default zone radius
  bool _isMovable = false;
  List<bool> _isSelected = [false, true, false]; // "Current" is the default selected
  String _zoneType = 'Current'; // Default to "Current" zone
  LatLng? _homeLocation;
  LatLng? _currentLocation; // New "Current" zone location
  LatLng? _workLocation;
  double? _homeRadius;
  double? _currentRadius; // New "Current" zone radius
  double? _workRadius;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadSavedData(); // Load saved locations and radius on startup

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus;
      });
    });

    _searchController.addListener(() {
      setState(() {
        _isSearching = _searchController.text.isNotEmpty;
      });
    });
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled.');
        return;
      }
    }

    var permissionStatus = await Permission.location.status;
    if (permissionStatus.isDenied) {
      permissionStatus = await Permission.location.request();
      if (permissionStatus.isDenied) {
        _showSnackBar('Location permission denied.');
        return;
      }
    } else if (permissionStatus.isPermanentlyDenied) {
      _showSnackBar('Location permission permanently denied. Please enable it from settings.');
      return;
    }

    final userLocation = await _location.getLocation();
    if (mounted) {
      setState(() {
        _userPosition = LatLng(userLocation.latitude ?? 0.0, userLocation.longitude ?? 0.0);
        _currentLocation = _userPosition; // Set initial "Current" location to user position
        _searchedPosition = _currentLocation; // Display "Current" location as the initial position
        _locationLoaded = true;
      });
    }
  }

  Future<void> _saveToPrefs(String locationKey, String radiusKey, LatLng location, double radius) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(locationKey, jsonEncode({'lat': location.latitude, 'lon': location.longitude}));
    prefs.setDouble(radiusKey, radius);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    final homeLocationString = prefs.getString('homeLocation');
    final currentLocationString = prefs.getString('currentLocation'); // New "Current" zone
    final workLocationString = prefs.getString('workLocation');
    _homeRadius = prefs.getDouble('homeRadius') ?? 150.0;
    _currentRadius = prefs.getDouble('currentRadius') ?? 150.0; // New "Current" zone
    _workRadius = prefs.getDouble('workRadius') ?? 150.0;

    if (homeLocationString != null) {
      final homeData = jsonDecode(homeLocationString);
      _homeLocation = LatLng(homeData['lat'], homeData['lon']);
    }

    if (currentLocationString != null) {
      final currentData = jsonDecode(currentLocationString);
      _currentLocation = LatLng(currentData['lat'], currentData['lon']);
    } else {
      // If no saved "Current" location, set it to the user's location
      _currentLocation = _userPosition;
    }

    if (workLocationString != null) {
      final workData = jsonDecode(workLocationString);
      _workLocation = LatLng(workData['lat'], workData['lon']);
    }

    setState(() {
      _radius = _currentRadius ?? _radius; // Set radius to "Current" zone radius initially
      _searchedPosition = _currentLocation; // Center map on "Current" location at startup
    });
  }

  void _toggleZoneType(int index) {
    setState(() {
      for (int i = 0; i < _isSelected.length; i++) {
        _isSelected[i] = i == index;
      }
      _zoneType = index == 0
          ? 'Home'
          : index == 1
              ? 'Current'
              : 'Work';

      if (_zoneType == 'Home') {
        _searchedPosition = _homeLocation;
        _radius = _homeRadius ?? _radius;
      } else if (_zoneType == 'Current') {
        _searchedPosition = _currentLocation;
        _radius = _currentRadius ?? _radius;
      } else {
        _searchedPosition = _workLocation;
        _radius = _workRadius ?? _radius;
      }

      if (_searchedPosition != null) {
        _mapController.move(_searchedPosition!, _zoomLevel);
      }
    });
  }

  void _saveCurrentLocation() {
    if (_searchedPosition != null) {
      setState(() {
        if (_zoneType == 'Home') {
          _homeLocation = _searchedPosition;
          _homeRadius = _radius;
          _saveToPrefs('homeLocation', 'homeRadius', _homeLocation!, _homeRadius!);
          _showSnackBar("Home location and radius saved.");
        } else if (_zoneType == 'Current') {
          _currentLocation = _searchedPosition;
          _currentRadius = _radius;
          _saveToPrefs('currentLocation', 'currentRadius', _currentLocation!, _currentRadius!);
          _showSnackBar("Current location and radius saved.");
        } else if (_zoneType == 'Work') {
          _workLocation = _searchedPosition;
          _workRadius = _radius;
          _saveToPrefs('workLocation', 'workRadius', _workLocation!, _workRadius!);
          _showSnackBar("Work location and radius saved.");
        }
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _searchAddress(String query, {int retries = 3}) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5');

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _suggestions = List<Map<String, dynamic>>.from(data);
          });
          return;
        } else {
          _showSnackBar("Error fetching address suggestions: ${response.statusCode}");
          print("Error ${response.statusCode}: ${response.body}");
          return;
        }
      } on TimeoutException catch (_) {
        if (attempt == retries - 1) {
          _showSnackBar("Connection timed out. Please try again later.");
          print("Timeout error on final attempt");
        }
      } catch (e) {
        _showSnackBar("An error occurred: $e");
        print("Exception: $e");
        return;
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchAddress(query);
      } else {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
      }
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel++;
    });
    _mapController.move(
      _searchedPosition ?? _userPosition!,
      _zoomLevel,
    );
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel--;
    });
    _mapController.move(
      _searchedPosition ?? _userPosition!,
      _zoomLevel,
    );
  }

  void _goToUserLocation() {
    if (_userPosition != null) {
      _mapController.move(_userPosition!, _zoomLevel);
      setState(() {
        _searchedPosition = _userPosition;
      });
    }
  }

  TileLayer get openStreetMapTileLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'dev.fleaflet.flutter_map.example',
      );

  void _toggleMovable() {
    setState(() {
      _isMovable = !_isMovable;
    });
    if (_isMovable) {
      _showSnackBar("Move mode: Drag marker to position, then tap to save.");
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final lat = double.parse(suggestion['lat']);
    final lon = double.parse(suggestion['lon']);

    setState(() {
      _searchedPosition = LatLng(lat, lon);
      _suggestions = [];
      _searchController.text = suggestion['display_name'];
      _isSearching = false;
    });

    _mapController.move(_searchedPosition!, _zoomLevel);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select location and zone radius'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: "Search for an address",
                    prefixIcon: Icon(Icons.search),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                  onChanged: _onSearchChanged,
                ),
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        title: Text(suggestion['display_name']),
                        subtitle: suggestion['address'] != null
                            ? Text(suggestion['address']['road'] ?? '')
                            : null,
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              Expanded(
                child: _locationLoaded
                    ? FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLocation!, // Set initial center to "Current" location
                          initialZoom: _zoomLevel,
                          interactionOptions: InteractionOptions(
                            flags: _isMovable ? InteractiveFlag.none : ~InteractiveFlag.doubleTapZoom,
                          ),
                        ),
                        children: [
                          openStreetMapTileLayer,
                          if (_searchedPosition != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _searchedPosition!,
                                  color: Colors.blue.withOpacity(0.2),
                                  borderStrokeWidth: 1,
                                  borderColor: Colors.blue,
                                  useRadiusInMeter: true,
                                  radius: _radius,
                                ),
                              ],
                            ),
                          if (_searchedPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: _searchedPosition!,
                                  child: GestureDetector(
                                    onDoubleTap: _toggleMovable,
                                    onPanUpdate: (details) {
                                      if (_isMovable) {
                                        final newLatitude = _searchedPosition!.latitude - details.delta.dy * 0.00001;
                                        final newLongitude = _searchedPosition!.longitude + details.delta.dx * 0.00001;
                                        setState(() {
                                          _searchedPosition = LatLng(newLatitude, newLongitude);
                                        });
                                      }
                                    },
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isMovable)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 4.0, horizontal: 8.0),
                                              margin: const EdgeInsets.only(bottom: 8.0),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                              child: const Text(
                                                "Move Mode: Tap to save",
                                                style: TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                          Icon(
                                            Icons.location_pin,
                                            color: _isMovable ? Colors.orange : Colors.blue,
                                            size: 40.0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                  mini: true,
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                  mini: true,
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _saveCurrentLocation,
                  child: const Icon(Icons.save),
                  mini: true,
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _goToUserLocation,
                  child: const Icon(Icons.home),
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isSearching
          ? null
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Adjust Zone Radius (meters)'),
                  Slider(
                    value: _radius,
                    min: 50.0,
                    max: 500.0,
                    divisions: 18,
                    label: '${_radius.round()} meters',
                    onChanged: (value) {
                      setState(() {
                        _radius = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text('Select Zone Type'),
                  ToggleButtons(
                    isSelected: _isSelected,
                    onPressed: _toggleZoneType,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Home'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Current'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Work'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Current Zone: $_zoneType'),
                ],
              ),
            ),
    );
  }
}
