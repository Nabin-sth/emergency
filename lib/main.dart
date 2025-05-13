import 'package:emergency/location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// 192.168.1.103
const String baseUrl = 'http://192.168.1.103:10000';
const String gpsEndpoint = '$baseUrl/api/v1/gps-data';
const String logsEndpoint = '$baseUrl/api/v1/logs';

class GpsData {
  final double latitude;
  final double longitude;

  GpsData({required this.latitude, required this.longitude});

  factory GpsData.fromJson(Map<String, dynamic> json) {
    return GpsData(
      latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
    );
  }
}

class SocketService {
  late IO.Socket socket;

  void initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
    });

    socket.onConnect((_) {
      print('Connected to Socket.IO server');
    });

    socket.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });

    socket.onError((error) {
      print('Socket.IO error: $error');
    });
  }

  void listenForUpdates(Function(GpsData) onUpdate) {
    socket.on('gpsData', (data) {
      try {
        print("called socket");
        final parsedData = GpsData.fromJson(data);
        print(parsedData.latitude);
        onUpdate(parsedData);
      } catch (e) {
        print("Error parsing socket data: $e");
      }
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPS Location App',
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  double latitude = 37.7749;
  double longitude = -122.4194;
  bool isLoading = true;
  double zoomLevel = 5.0;
  final MapController _mapController = MapController();
  LatLng? userLocation;
  Position? _currentPosition;
  String lastFetchTime = 'Not fetched yet';
  List<Map<String, dynamic>> logs = [];

  Timer? timer;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    fetchLocationData();
    _getCurrentLocation();
    _initNotifications();
    fetchLogs();
    _socketService.initSocket();
    _socketService.listenForUpdates(_handleGpsUpdate);
  }

  @override
  void dispose() {
    timer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }

  void _handleGpsUpdate(GpsData data) {
    if (latitude != data.latitude || longitude != data.longitude) {
      setState(() {
        latitude = data.latitude;
        longitude = data.longitude;
        lastFetchTime = DateFormat('h:mm a, MMMM d, y').format(DateTime.now());
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(LatLng(latitude, longitude), zoomLevel);
        }
      });

      Vibration.vibrate(duration: 500);
      _showNotification();
    }
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      'Location Updated',
      'New location fetched from the server.',
      platformChannelSpecifics,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw 'Location permissions are denied';
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      });
    } catch (e) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text('Location Error'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> fetchLocationData() async {
    try {
      final response = await http.get(Uri.parse(gpsEndpoint));
      if (response.statusCode == 200) {
        final data = GpsData.fromJson(json.decode(response.body));
        _handleGpsUpdate(data);
        setState(() {
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch data from API');
      }
    } catch (e) {
      print("Error while fetching data: ${e}");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchLogs() async {
    try {
      final response = await http.get(Uri.parse(logsEndpoint));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          logs = data.map((log) => log as Map<String, dynamic>).toList();
        });
      } else {
        throw Exception('Failed to fetch logs from API');
      }
    } catch (e) {
      print("Error fetching logs: $e");
    }
  }

  void _navigateToLogsScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => LogsScreen(logs: logs)));
  }

  void navigateToWeatherScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                WeatherScreen(latitude: latitude, longitude: longitude),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS Location'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: fetchLocationData),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _navigateToLogsScreen,
          ),
          IconButton(
            icon: Icon(Icons.sunny),
            onPressed: navigateToWeatherScreen,
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(latitude, longitude),
                      initialZoom: zoomLevel,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                      interactionOptions: InteractionOptions(
                        flags:
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                          if (userLocation != null)
                            Marker(
                              point: userLocation!,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.person_pin_circle,
                                size: 40,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Last Fetch: $lastFetchTime'),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class LogsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  LogsScreen({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Incident History & Logs')),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final time = DateTime.parse(log['createdAt']);
          final formattedTime = DateFormat('h:mm a, MMMM d, y').format(time);

          return ListTile(
            title: Text(
              'Latitude: ${log["latitude"]}, Longitude: ${log['longitude']}',
            ),
            subtitle: Text('Time: $formattedTime'),
          );
        },
      ),
    );
  }
}
