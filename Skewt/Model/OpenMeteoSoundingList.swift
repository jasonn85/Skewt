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
        data = [:]
    }
    
    struct OpenMeteoData: Decodable {
        let latitude: Double
        let longitude: Double
        let elevation: Int
        
        let hourlyUnits: HourlyUnits?
        let hourly: HourlyData?
        
        enum CodingKeys: CodingKey {
            case latitude
            case longitude
            case elevation
            case hourlyUnits
            case hourly
        }
        
        struct HourlyUnits: Decodable {
            let time: TimeUnit
            
            let temperature: [Int: TemperatureUnit]
            let relativeHumidity: [Int: RelativeHumidityUnit]
            let windSpeed: [Int: WindSpeedUnit]
            let windDirection: [Int: WindDirectionUnit]
            
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
        
        struct HourlyData: Decodable {
            
        }
    }
    
    
    enum ParseError: Error {
        case empty
        case unparseable
        case missingLocation
    }
}


