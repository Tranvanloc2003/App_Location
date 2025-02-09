import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class LocationScreens extends StatefulWidget {
  const LocationScreens({super.key});

  @override
  State<LocationScreens> createState() => _LocationScreensState();
}

class _LocationScreensState extends State<LocationScreens> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  Location _location = Location();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = true;
  LatLng? _destinationLocation;
  List<LatLng> _route = [];
  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (!await _checkTheRequestPermission()) return;
    // lang nghe cap nhat vi tri vaf cap nhat cho den khi dung vi tri nguoi dung
    _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _isLoading = false; // dung tai sau khi co vi tri
        });
      }
    });
  }

// Phương thức để lấy tọa độ cho một địa điểm đã cho sử dụng LocationApp Nominatim API.
  Future<void> fetchCondinatesPoint(String location) async {
    final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1");
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]["lat"]);
        final lon = double.parse(data[0]["lon"]);
        setState(() {
          _destinationLocation = LatLng(lat, lon);
        });
        await _fetchRoute();
      } else {
        errorMessage("Không tìm thấy địa chỉ");
      }
    } else {
      errorMessage("Lỗi địa chỉ không xác định");
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destinationLocation == null) return;
    final uri = Uri.parse(
        "http://router.project-osrm.org/route/v1/driving/"'${_currentLocation!.longitude},${_currentLocation!.latitude};''${_destinationLocation!.longitude},${_destinationLocation!.latitude}?overview=full&geometries=polyline');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      _decodePolyline(geometry);
    } else {
      errorMessage("Không tìm thấy đường đi");
    }
  }

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPolyline =
        polylinePoints.decodePolyline(encodedPolyline);
    setState(() {
      _route = decodedPolyline
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    });
  }

  Future<bool> _checkTheRequestPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    //cap quyen xem vi tri
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;     
    }
    return true;
  }

  Future<void> _userCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Vị trí này không khả dụng"),
      ));
    }
  }

//phuong thuc thong bao loi
  void errorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text("Location App"),
        backgroundColor: Colors.lightBlue,
      ),
      body: Stack(

        children: [
          _isLoading ? Center(child: CircularProgressIndicator()) :
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? LatLng(0, 0),
              initialZoom: 2,
              minZoom: 0,
              maxZoom: 100,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              CurrentLocationLayer(
                style: LocationMarkerStyle(
                  marker: DefaultLocationMarker(
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                    ),
                  ),
                  markerSize: Size(35, 35),
                  markerDirection: MarkerDirection.heading,
                ),
              ),
              if (_destinationLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _destinationLocation!,
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                if(_currentLocation != null && _destinationLocation != null && _route.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _route,strokeWidth: 5,color: Colors.red),
                ])
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Nhập địa chỉ",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                      onPressed: () {
                        final location = _locationController.text.trim();
                        if (location.isNotEmpty) {
                          fetchCondinatesPoint(location);
                        }
                      },
                      icon: Icon(Icons.search))
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _userCurrentLocation,
        backgroundColor: Colors.lightBlue,
        elevation: 0.0,
        child: Icon(
          Icons.my_location,
          size: 30,
          color: Colors.white,
        ),
      ),
    );
  }
}
