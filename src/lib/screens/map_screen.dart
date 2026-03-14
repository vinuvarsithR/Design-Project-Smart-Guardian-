import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_service.dart';

class MapScreen extends StatefulWidget {
  final bool selectMode;
  final double? initialLat;
  final double? initialLng;
  final String? userId; // Link the geofence to a specific user

  const MapScreen({
    super.key,
    required this.selectMode,
    this.initialLat,
    this.initialLng,
    this.userId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng? _selectedLocation;
  Circle? _geofenceCircle;
  bool _locationPermissionGranted = false;
  bool _loading = true;

  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await _checkLocationPermission();
    setState(() => _loading = false);
  }

  // ✅ Request location permissions
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable location services.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    setState(() {
      _locationPermissionGranted =
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);
    });
  }

  // ✅ Move camera to current position
  Future<void> _goToCurrentLocation() async {
    if (!_locationPermissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission not granted.")),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error getting location: $e")),
      );
    }
  }

  // ✅ Save geofence to Firestore
  Future<void> _saveGeofence() async {
    if (widget.userId == null || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location first.")),
      );
      return;
    }

    try {
      await _firestore.setGeofence(
        widget.userId!,
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
        _geofenceCircle?.radius ?? 100,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Geofence saved successfully!")),
      );
      Navigator.pop(context, _selectedLocation);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save geofence: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Geofence Area"),
        actions: [
          if (widget.selectMode)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: "Save Geofence",
              onPressed: _selectedLocation == null
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tap on the map to select a location."),
                        ),
                      )
                  : _saveGeofence,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Go to current location",
        onPressed: _goToCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target:
              LatLng(widget.initialLat ?? 13.0827, widget.initialLng ?? 80.2707),
          zoom: 14,
        ),
        onMapCreated: (controller) => _controller = controller,
        myLocationEnabled: _locationPermissionGranted,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        onTap: widget.selectMode
            ? (pos) {
                setState(() {
                  _selectedLocation = pos;
                  _geofenceCircle = Circle(
                    circleId: const CircleId('geofence'),
                    center: pos,
                    radius: 100,
                    fillColor: Colors.blue.withOpacity(0.2),
                    strokeColor: Colors.blue,
                    strokeWidth: 2,
                  );
                });
              }
            : null,
        markers: {
          if (_selectedLocation != null)
            Marker(
              markerId: const MarkerId('selected'),
              position: _selectedLocation!,
              infoWindow: const InfoWindow(title: "Selected Location"),
            ),
        },
        circles: {
          if (_geofenceCircle != null) _geofenceCircle!,
        },
      ),
    );
  }
}
