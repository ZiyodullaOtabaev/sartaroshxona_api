import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _selectedLocation = const LatLng(41.311081, 69.240562);
  GoogleMapController? _mapController;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;

      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted) return;

      final locationData = await location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final userLatLng = LatLng(locationData.latitude!, locationData.longitude!);
        setState(() {
          _selectedLocation = userLatLng;
          _locationLoaded = true;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(userLatLng, 16),
        );
      }
    } catch (e) {
      debugPrint("Geolokatsiya xatolik: $e");
    }
  }

  void _onTap(LatLng location) {
    setState(() => _selectedLocation = location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manzilni belgilang"),
        backgroundColor: const Color(0xFF1A1F2B),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF2ECC71)),
            onPressed: () => Navigator.pop(context, _selectedLocation),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 15),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId("selected"),
                position: _selectedLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            },
          ),
          // Loading indicator
          if (!_locationLoaded)
            Positioned(
              top: 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 8),
                      Text("Joylashuvingiz aniqlanmoqda...", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
