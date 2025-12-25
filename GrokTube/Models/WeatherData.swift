//
//  WeatherData.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation

/// Weather data model from Open-Meteo API
struct WeatherResponse: Codable {
    let current: CurrentWeather
    let hourly: HourlyWeather?
    
    enum CodingKeys: String, CodingKey {
        case current
        case hourly
    }
}

struct CurrentWeather: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Int
    let apparentTemperature: Double
    let isDay: Int
    let precipitation: Double
    let weatherCode: Int
    let windSpeed10m: Double
    
    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case isDay = "is_day"
        case precipitation
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
    }
}

struct HourlyWeather: Codable {
    let time: [String]
    let temperature2m: [Double]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
    }
}

/// Parsed weather for UI display
struct ParsedWeather {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let condition: WeatherCondition
    let isDay: Bool
    let windSpeed: Double
    let precipitation: Double
    
    var temperatureString: String {
        String(format: "%.0f°C", temperature)
    }
    
    var feelsLikeString: String {
        String(format: "Feels like %.0f°C", feelsLike)
    }
    
    var description: String {
        "\(condition.description), \(temperatureString)"
    }
    
    var recommendation: String {
        switch condition {
        case .clearSky, .mainlyClear, .partlyCloudy:
            return "Perfect weather for a peaceful park visit! ☀️"
        case .overcast, .foggy:
            return "Overcast but great for a quiet stroll 🌫️"
        case .drizzle, .lightRain:
            return "Light rain - bring an umbrella or find covered spots 🌧️"
        case .rain, .heavyRain:
            return "Rainy day - try the Barbican Conservatory instead! 🌧️"
        case .snow:
            return "Snowy! The parks will be magical but wrap up warm ❄️"
        case .thunderstorm:
            return "Storm warning - best to stay indoors today ⛈️"
        }
    }
}

/// Weather condition from WMO weather codes
enum WeatherCondition: Int {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case foggy = 45
    case drizzle = 51
    case lightRain = 61
    case rain = 63
    case heavyRain = 65
    case snow = 71
    case thunderstorm = 95
    
    init(code: Int) {
        switch code {
        case 0: self = .clearSky
        case 1: self = .mainlyClear
        case 2: self = .partlyCloudy
        case 3: self = .overcast
        case 45, 48: self = .foggy
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61: self = .lightRain
        case 63: self = .rain
        case 65, 66, 67: self = .heavyRain
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .thunderstorm
        default: self = .partlyCloudy
        }
    }
    
    var description: String {
        switch self {
        case .clearSky: return "Clear sky"
        case .mainlyClear: return "Mainly clear"
        case .partlyCloudy: return "Partly cloudy"
        case .overcast: return "Overcast"
        case .foggy: return "Foggy"
        case .drizzle: return "Drizzle"
        case .lightRain: return "Light rain"
        case .rain: return "Moderate rain"
        case .heavyRain: return "Heavy rain"
        case .snow: return "Snow"
        case .thunderstorm: return "Thunderstorm"
        }
    }
    
    var icon: String {
        switch self {
        case .clearSky: return "sun.max.fill"
        case .mainlyClear: return "sun.min.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .overcast: return "cloud.fill"
        case .foggy: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .lightRain: return "cloud.rain.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .snow: return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }
    
    var iconColor: String {
        switch self {
        case .clearSky, .mainlyClear: return "yellow"
        case .partlyCloudy: return "orange"
        case .overcast, .foggy: return "gray"
        case .drizzle, .lightRain, .rain, .heavyRain: return "blue"
        case .snow: return "cyan"
        case .thunderstorm: return "purple"
        }
    }
}
