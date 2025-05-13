import 'package:emergency/weather_model.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherService {
  // final String apiKey =
  // '95d94c19737b216a26131f9952aac69a'; // Replace with your API key

  Future<Weather> fetchWeather(double latitude, double longitude) async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather?lat=${latitude}&lon=${longitude}&appid=95d94c19737b216a26131f9952aac69a",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Weather.fromJson(data);
    } else {
      throw Exception('Failed to fetch weather data');
    }
  }
}

class WeatherScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  WeatherScreen({required this.latitude, required this.longitude});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  Weather? _weather;
  bool _isLoading = false;

  Future<void> _fetchWeather(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final weather = await _weatherService.fetchWeather(latitude, longitude);
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch weather: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GPS Location')),
      body: Column(
        children: [
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else if (_weather != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temperature: ${_weather!.temperature.toStringAsFixed(1)}°C',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Feels Like: ${_weather!.feelsLike.toStringAsFixed(1)}°C',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Min/Max: ${_weather!.tempMin.toStringAsFixed(1)}°C / ${_weather!.tempMax.toStringAsFixed(1)}°C',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Condition: ${_weather!.condition} (${_weather!.description})',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Image.network(
                    'https://openweathermap.org/img/wn/${_weather!.icon}@2x.png',
                    width: 50,
                    height: 50,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Wind: ${_weather!.windSpeed} m/s, ${_weather!.windDirection}°',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Humidity: ${_weather!.humidity}%',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Pressure: ${_weather!.pressure} hPa',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Visibility: ${_weather!.visibility / 1000} km',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Sunrise: ${DateFormat('h:mm a').format(_weather!.sunrise)}',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Sunset: ${DateFormat('h:mm a').format(_weather!.sunset)}',
                    style: TextStyle(fontSize: 18),
                  ),
                  if (_weather!.rainVolume != null)
                    Text(
                      'Rain: ${_weather!.rainVolume} mm',
                      style: TextStyle(fontSize: 18),
                    ),
                  if (_weather!.snowVolume != null)
                    Text(
                      'Snow: ${_weather!.snowVolume} mm',
                      style: TextStyle(fontSize: 18),
                    ),
                ],
              ),
            ),
          ElevatedButton(
            onPressed: () {
              _fetchWeather(
                widget.latitude,
                widget.longitude,
              ); // Fetch weather for the victim's location
            },
            child: Text('Get Weather'),
          ),
        ],
      ),
    );
  }
}
