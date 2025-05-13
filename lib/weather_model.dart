class Weather {
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final String condition;
  final String description;
  final String icon;
  final double windSpeed;
  final int windDirection;
  final int humidity;
  final int pressure;
  final int visibility;
  final DateTime sunrise;
  final DateTime sunset;
  final double? rainVolume;
  final double? snowVolume;

  Weather({
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.windDirection,
    required this.humidity,
    required this.pressure,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    this.rainVolume,
    this.snowVolume,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: json['main']['temp'] - 273.15,
      feelsLike: json['main']['feels_like'] - 273.15,
      tempMin: json['main']['temp_min'] - 273.15,
      tempMax: json['main']['temp_max'] - 273.15,
      condition: json['weather'][0]['main'],
      description: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      windSpeed: json['wind']['speed'],
      windDirection: json['wind']['deg'],
      humidity: json['main']['humidity'],
      pressure: json['main']['pressure'],
      visibility: json['visibility'],
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        json['sys']['sunrise'] * 1000,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(json['sys']['sunset'] * 1000),
      rainVolume: json['rain']?['1h'] ?? json['rain']?['3h'],
      snowVolume: json['snow']?['1h'] ?? json['snow']?['3h'],
    );
  }
}
