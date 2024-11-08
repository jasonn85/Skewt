//
//  OpenMeteoSoundingList.swift
//  Skewt
//
//  Created by Jason Neel on 11/4/24.
//

import Foundation
import CoreLocation

struct OpenMeteoSoundingList {
    let fetchTime: Date
    let location: CLLocation
    
    let data: [Date: SoundingData]
}

extension OpenMeteoSoundingList {
    init(fromData jsonData: Data) throws {
        guard jsonData.count > 0 else {
            throw ParseError.empty
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let response = try? decoder.decode(OpenMeteoData.self, from: jsonData) else {
            throw ParseError.unparseable
        }
        
        fetchTime = Date()
        location = CLLocation(latitude: response.latitude, longitude: response.longitude)
        
        var data = [Date: SoundingData]()
        
        let dates = response.hourly?.times ?? []
        let pressures = response.hourlyUnits?.allPressures.sorted() ?? []
        
        dates.forEach { date in
            data[date] = SoundingData(
                time: date,
                elevation: response.elevation,
                dataPoints: pressures.map { pressure in
                    SoundingData.Point(
                        pressure: Double(pressure),
                        height: nil,
                        temperature: response.hourly?.temperature[date]?[pressure],
                        // TODO: Calculate dew point
                        dewPoint: response.hourly?.relativeHumidity[date]?[pressure] != nil ? Double(response.hourly!.relativeHumidity[date]![pressure]!) : nil,
                        windDirection: response.hourly?.windDirection[date]?[pressure],
                        windSpeed: response.hourly?.windSpeed[date]?[pressure]
                    )
                },
                surfaceDataPoint: nil,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )
        }
        
        self.data = data
    }
    
    struct OpenMeteoData: Decodable {
        let latitude: Double
        let longitude: Double
        let elevation: Int
        
        let hourlyUnits: HourlyUnits?
        let hourly: HourlyData?
        
        struct HourlyUnits: Decodable {
            let time: TimeUnit
            
            let temperature: [Int: TemperatureUnit]
            let relativeHumidity: [Int: RelativeHumidityUnit]
            let windSpeed: [Int: WindSpeedUnit]
            let windDirection: [Int: WindDirectionUnit]
            
            var allPressures: Set<Int> {
                Set(temperature.keys).union(Set(relativeHumidity.keys).union(Set(windSpeed.keys).union(Set(windDirection.keys))))
            }
            
            enum TimeUnit: String, Decodable {
                case iso8601 = "iso8601"
                case unixTime = "unixtime"
            }
            
            enum TemperatureUnit: String, Decodable {
                case celsius = "°C"
                case fahrenheit = "°F"
            }
            
            enum RelativeHumidityUnit: String, Decodable {
                case percent = "%"
            }
            
            enum WindSpeedUnit: String, Decodable {
                case kph = "km/h"
                case ms = "m/s"
                case mph = "mp/h"
                case kn = "kn"
            }
            
            enum WindDirectionUnit: String, Decodable {
                case degrees = "°"
            }
            
            struct HourlyUnitKey: CodingKey {
                var stringValue: String
                var intValue: Int? { nil }
                init?(intValue: Int) { nil }
                
                init(stringValue: String) {
                    self.stringValue = stringValue
                }
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: HourlyUnitKey.self)
                
                time = try container.decode(TimeUnit.self, forKey: HourlyUnitKey(stringValue: "time"))
                
                var temperature: [Int: TemperatureUnit] = [:]
                var relativeHumidity: [Int: RelativeHumidityUnit] = [:]
                var windSpeed: [Int: WindSpeedUnit] = [:]
                var windDirection: [Int: WindDirectionUnit] = [:]
                
                try container.allKeys.forEach { key in
                    let r = /([A-Za-z]+)(\d+0)Hpa/
                    
                    guard let match = key.stringValue.firstMatch(of: r), let pressure = Int(match.output.2) else {
                        return
                    }
                    
                    let keyName = String(match.output.1)
                    
                    switch keyName {
                    case "temperature":
                        temperature[pressure] = try container.decode(TemperatureUnit.self, forKey: key)
                    case "relativeHumidity":
                        relativeHumidity[pressure] = try container.decode(RelativeHumidityUnit.self, forKey: key)
                    case "windSpeed":
                        windSpeed[pressure] = try container.decode(WindSpeedUnit.self, forKey: key)
                    case "windDirection":
                        windDirection[pressure] = try container.decode(WindDirectionUnit.self, forKey: key)
                    default:
                        return
                    }
                }
                
                self.temperature = temperature
                self.relativeHumidity = relativeHumidity
                self.windSpeed = windSpeed
                self.windDirection = windDirection
            }
        }
        
        struct HourlyData: DecodableWithConfiguration {
            init(from decoder: any Decoder, configuration: HourlyUnits?) throws {
                let container = try decoder.container(keyedBy: HourlyDataKey.self)
                
                var times: [Date]
                var temperature: [Date: [Int: Double]] = [:]
                var relativeHumidity: [Date: [Int: Int]] = [:]
                var windSpeed: [Date: [Int: Double]] = [:]
                var windDirection: [Date: [Int: Int]] = [:]
                
                let timeKey = HourlyDataKey(stringValue: "time")
                
                switch configuration?.time {
                case .iso8601:
                    let dateStrings = try container.decode([String].self, forKey: timeKey)
                    let formatter = ISO8601DateFormatter()
                    times = try dateStrings.map {
                        guard let date = formatter.date(from: $0) else {
                            throw ParseError.unparseableDate($0)
                        }
                        
                        return date
                    }
                case .unixTime:
                    fallthrough
                default:
                    let dateInts = try container.decode([Int].self, forKey: timeKey)
                    times = dateInts.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                }
                
                try container.allKeys.forEach { key in
                    let r = /([A-Za-z]+)(\d+0)Hpa/
                    
                    guard let match = key.stringValue.firstMatch(of: r), let pressure = Int(match.output.2) else {
                        return
                    }
                    
                    let keyName = String(match.output.1)
                    
                    switch keyName {
                    case "temperature":
                        for (dateIndex, temperatureThisPressure) in try container.decode([Double].self, forKey: key).enumerated() {
                            if temperature[times[dateIndex]] == nil {
                                temperature[times[dateIndex]] = [:]
                            }

                            temperature[times[dateIndex]]![pressure] = temperatureThisPressure
                        }
                    case "relativeHumidity":
                        for (dateIndex, humidityThisPressure) in try container.decode([Int].self, forKey: key).enumerated() {
                            if relativeHumidity[times[dateIndex]] == nil {
                                relativeHumidity[times[dateIndex]] = [:]
                            }
                                
                            relativeHumidity[times[dateIndex]]![pressure] = humidityThisPressure
                        }
                    case "windSpeed":
                        for (dateIndex, windSpeedThisPressure) in try container.decode([Double].self, forKey: key).enumerated() {
                            if windSpeed[times[dateIndex]] == nil {
                                    
                                windSpeed[times[dateIndex]] = [:]
                            }
                                
                            windSpeed[times[dateIndex]]![pressure] = windSpeedThisPressure
                        }
                    case "windDirection":
                        for (dateIndex, windDirectionThisPressure) in try container.decode([Int].self, forKey: key).enumerated() {
                            if windDirection[times[dateIndex]] == nil {
                                windDirection[times[dateIndex]] = [:]
                            }
                            
                            windDirection[times[dateIndex]]![pressure] = windDirectionThisPressure
                        }
                    default:
                        // Happily gnore a key that does not match our expected name/pressure format
                        return
                    }
                }
                
                self.times = times
                self.temperature = temperature
                self.relativeHumidity = relativeHumidity
                self.windSpeed = windSpeed
                self.windDirection = windDirection
            }
            
            typealias DecodingConfiguration = HourlyUnits?
            
            let times: [Date]
            
            // Values keyed by pressure keyed by timestamp
            let temperature: [Date: [Int: Double]]
            let relativeHumidity: [Date: [Int: Int]]
            let windSpeed: [Date: [Int: Double]]
            let windDirection: [Date: [Int: Int]]
            
            struct HourlyDataKey: CodingKey {
                var stringValue: String
                var intValue: Int? { nil }
                init?(intValue: Int) { nil }
                
                init(stringValue: String) {
                    self.stringValue = stringValue
                }
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case latitude = "latitude"
            case longitude = "longitude"
            case elevation = "elevation"
            case hourlyUnits = "hourlyUnits"
            case hourly = "hourly"
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            latitude = try container.decode(Double.self, forKey: .latitude)
            longitude = try container.decode(Double.self, forKey: .longitude)
            elevation = try container.decode(Int.self, forKey: .elevation)
            hourlyUnits = try container.decode(HourlyUnits.self, forKey: .hourlyUnits)
            hourly = try container.decode(HourlyData.self, forKey: .hourly, configuration: hourlyUnits)
        }
    }
    
    enum ParseError: Error {
        case empty
        case unparseable
        case unparseableDate(String?)
        case missingLocation
    }
}
