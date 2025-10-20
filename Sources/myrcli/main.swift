//
//  main.swift
//  Core Location CLI
//
//  Created by William Entriken on 2016-01-12.
//  Copyright © 2016 William Entriken. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - Weather API Models
struct WeatherResponse: Codable {
    let properties: WeatherProperties
}

struct WeatherProperties: Codable {
    let timeseries: [WeatherTimeseries]
}

struct WeatherTimeseries: Codable {
    let time: String
    let data: WeatherData
}

struct WeatherData: Codable {
    let instant: WeatherInstant
    let next_1_hours: WeatherPeriod?
    let next_6_hours: WeatherPeriod?
}

struct WeatherInstant: Codable {
    let details: InstantDetails
}

struct InstantDetails: Codable {
    let air_temperature: Double
    let wind_speed: Double
    let wind_from_direction: Double?
    let precipitation_amount: Double?
}

struct WeatherPeriod: Codable {
    let summary: WeatherSummary
    let details: PeriodDetails
}

struct WeatherSummary: Codable {
    let symbol_code: String
}

struct PeriodDetails: Codable {
    let precipitation_amount: Double?
}

class Delegate: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    var timeoutTimer: Timer? = nil

    func start() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 2.0
        locationManager.delegate = self
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false, block: {_ in self.timeout()})
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    func timeout() {
        print("Fetching location timed out. Exiting.")
        exit(1)
    }

    func fetchWeather(for location: CLLocation, completion: @escaping (Result<WeatherResponse, Error>) -> Void) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(lat)&lon=\(lon)"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "myrcli", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        request.setValue("Myrcli \(version) / per.buer@gmail.com", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "myrcli", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                completion(.success(weatherResponse))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    func weatherSymbolToEmoji(_ symbolCode: String) -> String {
        // Map Met.no symbol codes to emoji
        if symbolCode.contains("clearsky") {
            return symbolCode.contains("night") ? "🌙" : "☀️"
        } else if symbolCode.contains("fair") {
            return symbolCode.contains("night") ? "🌙" : "🌤️"
        } else if symbolCode.contains("partlycloudy") {
            return "⛅"
        } else if symbolCode.contains("cloudy") {
            return "☁️"
        } else if symbolCode.contains("fog") {
            return "🌫️"
        } else if symbolCode.contains("heavyrain") || symbolCode.contains("rain") && symbolCode.contains("heavy") {
            return "🌧️"
        } else if symbolCode.contains("lightrain") || symbolCode.contains("rain") && symbolCode.contains("light") {
            return "🌦️"
        } else if symbolCode.contains("rain") {
            return "🌧️"
        } else if symbolCode.contains("sleet") {
            return "🌨️"
        } else if symbolCode.contains("snow") {
            return "❄️"
        } else if symbolCode.contains("thunder") {
            return "⛈️"
        } else {
            return "🌡️"
        }
    }

    func weatherSymbolToText(_ symbolCode: String) -> String {
        // Map Met.no symbol codes to human-friendly descriptions
        if symbolCode.contains("clearsky") {
            return "Clear Sky"
        } else if symbolCode.contains("fair") {
            return "Fair"
        } else if symbolCode.contains("partlycloudy") {
            return "Partly Cloudy"
        } else if symbolCode.contains("cloudy") {
            return "Cloudy"
        } else if symbolCode.contains("fog") {
            return "Fog"
        } else if symbolCode.contains("heavyrain") || symbolCode.contains("rain") && symbolCode.contains("heavy") {
            return "Heavy Rain"
        } else if symbolCode.contains("lightrain") || symbolCode.contains("rain") && symbolCode.contains("light") {
            return "Light Rain"
        } else if symbolCode.contains("rain") {
            return "Rain"
        } else if symbolCode.contains("sleet") {
            return "Sleet"
        } else if symbolCode.contains("snow") {
            return "Snow"
        } else if symbolCode.contains("thunder") {
            return "Thunderstorm"
        } else {
            return "Unknown"
        }
    }

    func bearingToCompassDirection(from: CLLocation, to: CLLocation) -> String {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let lon1 = from.coordinate.longitude * .pi / 180
        let lon2 = to.coordinate.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((bearing + 11.25) / 22.5) % 16
        return directions[index]
    }

    func formatLocationName(for location: CLLocation, placemark: CLPlacemark) -> String {
        var locationParts: [String] = []

        if let locality = placemark.locality {
            locationParts.append(locality)
        }
        if let country = placemark.country {
            locationParts.append(country)
        }

        let locationName = locationParts.joined(separator: ", ")

        if let placemarkLocation = placemark.location {
            let distance = location.distance(from: placemarkLocation) / 1000 // Convert to km

            if distance >= 5 {
                let direction = bearingToCompassDirection(from: placemarkLocation, to: location)
                return String(format: "%.0fkm %@ of %@", distance, direction, locationName)
            }
        }

        return locationName
    }

    func printWeather(_ weather: WeatherResponse, for location: CLLocation, locationName: String? = nil) {
        if let locationName = locationName {
            print("Weather forecast for \(locationName) (next 24 hours):")
        } else {
            print("Weather forecast (next 24 hours):")
        }

        let now = Date()
        let twentyFourHoursLater = now.addingTimeInterval(24 * 60 * 60)
        let dateFormatter = ISO8601DateFormatter()
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "HH:mm"
        displayFormatter.timeZone = TimeZone.current

        for entry in weather.properties.timeseries {
            guard let entryDate = dateFormatter.date(from: entry.time) else { continue }

            // Only show entries within next 24 hours
            if entryDate < now || entryDate > twentyFourHoursLater {
                continue
            }

            let timeStr = displayFormatter.string(from: entryDate)
            let temp = entry.data.instant.details.air_temperature
            let wind = entry.data.instant.details.wind_speed

            var line = String(format: "%@  %4.0f°C  %4.1fm/s", timeStr, temp, wind)

            // Add weather symbol and precipitation if available
            if let forecast = entry.data.next_1_hours ?? entry.data.next_6_hours {
                let emoji = weatherSymbolToEmoji(forecast.summary.symbol_code)
                let text = weatherSymbolToText(forecast.summary.symbol_code)
                line += "  \(emoji) \(text)"

                if let precip = forecast.details.precipitation_amount, precip > 0 {
                    line += String(format: " %.1fmm", precip)
                }
            }

            print(line)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        timeoutTimer!.invalidate()
        let location = locations.first!

        // Perform reverse geocoding to get location name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            var locationName: String? = nil

            if let placemark = placemarks?.first {
                locationName = self.formatLocationName(for: location, placemark: placemark)
            }

            // Fetch weather with location name
            self.fetchWeather(for: location) { result in
                switch result {
                case .success(let weather):
                    self.printWeather(weather, for: location, locationName: locationName)
                    exit(0)
                case .failure(let error):
                    print("Failed to fetch weather: \(error.localizedDescription)")
                    exit(1)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if error._code == 1 {
            print("myrcli: ❌ Location services are disabled or location access denied. Please visit System Preferences > Security & Privacy > Privacy > Location Services")
            exit(1)
        }
        print("myrcli: ❌ \(error.localizedDescription)")
        exit(1)
    }

    func help() {
        print("""
        USAGE: myrcli [--help] [--version]

               Gets your current location and displays the 24-hour weather forecast

        OPTIONS:
          -h, --help     Display this help message and exit
          --version      Display version information and exit
        """)
    }

    func version() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        print("myrcli version \(version)")
    }
}

let delegate = Delegate()
for argument in ProcessInfo().arguments {
    switch argument {
    case "-h", "--help":
        delegate.help()
        exit(0)
    case "--version":
        delegate.version()
        exit(0)
    default:
        break
    }
}

delegate.start()

autoreleasepool {
    RunLoop.main.run()
}
