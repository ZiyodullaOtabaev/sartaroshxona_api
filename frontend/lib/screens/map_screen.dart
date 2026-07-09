import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _selectedLocation = LatLng(41.311081, 69.240562); // Toshkent markazi default

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manzilni belgilang"),
        backgroundColor: Color(0xFF1A1F2B),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Color(0xFF2ECC71)),
            onPressed: () {
              // Tanlangan manzilni qaytarish
              Navigator.pop(context, _selectedLocation);
            },
          )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 14),
        onTap: _onTap,
        markers: {
          Marker(
            markerId: MarkerId("selected"),
            position: _selectedLocation,
          ),
        },
      ),
    );
  }
}