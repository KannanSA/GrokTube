//
//  WeatherService.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation
import CoreLocation

/// Service to fetch weather data from Open-Meteo API (free, no API key needed)
actor WeatherService {
    static let shared = WeatherService()
    
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    private var cache: (weather: ParsedWeather, timestamp: Date)?
    private let cacheValiditySeconds: TimeInterval = 600 // 10 minutes
    
    // London coordinates
    private let londonLatitude = 51.5074
    private let londonLongitude = -0.1278
    
    private init() {}
    
    /// Fetch current weather for London
    func fetchLondonWeather() async throws -> ParsedWeather {
        // Check cache first
        if let cached = cache,
           Date().timeIntervalSince(cached.timestamp) < cacheValiditySeconds {
            return cached.weather
        }
        
        return try await fetchWeather(latitude: londonLatitude, longitude: londonLongitude)
    }
    
    /// Fetch weather for a specific location
    func fetchWeather(latitude: Double, longitude: Double) async throws -> ParsedWeather {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "Europe/London"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(WeatherResponse.self, from: data)
        
        let parsed = ParsedWeather(
            temperature: weatherResponse.current.temperature2m,
            feelsLike: weatherResponse.current.apparentTemperature,
            humidity: weatherResponse.current.relativeHumidity2m,
            condition: WeatherCondition(code: weatherResponse.current.weatherCode),
            isDay: weatherResponse.current.isDay == 1,
            windSpeed: weatherResponse.current.windSpeed10m,
            precipitation: weatherResponse.current.precipitation
        )
        
        // Update cache
        cache = (parsed, Date())
        
        return parsed
    }
    
    /// Get weather summary for Grok to use
    func getWeatherSummaryForGrok() async -> String {
        do {
            let weather = try await fetchLondonWeather()
            return """
            Current London weather: \(weather.condition.description), \(weather.temperatureString) (feels like \(weather.feelsLikeString)).
            Wind: \(String(format: "%.0f", weather.windSpeed)) km/h. Humidity: \(weather.humidity)%.
            Recommendation: \(weather.recommendation)
            """
        } catch {
            return "Unable to fetch weather data. Assume typical London weather."
        }
    }
}

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid weather API URL"
        case .invalidResponse: return "Invalid response from weather service"
        case .decodingError: return "Could not parse weather data"
        }
    }
}
