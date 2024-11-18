//
//  OpenMeteoSoundingListDecoding.swift
//  Skewt
//
//  Created by Jason Neel on 11/14/24.
//

import Foundation

extension OpenMeteoSoundingList {
    init(fromData jsonData: Data) throws {
        guard jsonData.count > 0 else {
            throw ParseError.empty
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenMeteoData.self, from: jsonData)
        
        fetchTime = Date()
        latitude = response.latitude
        longitude = response.longitude
        
        var data = [Date: SoundingData]()
        
        let dates = response.hourly?.times ?? []
        let pressures = response.hourlyUnits?.allPressures.sorted() ?? []
        
        dates.forEach { date in
            let dataPoints = pressures.map { pressure in
                let temperature = response.hourly?.temperature[date]?[pressure]
                    .convertToCelsius(from: response.hourlyUnits?.temperature?[pressure])
                let dewPoint = response.hourly?.dewPoint[date]?[pressure]
                    .convertToCelsius(from: response.hourlyUnits?.dewPoint?[pressure])
                
                return SoundingData.Point(
                    pressure: Double(pressure),
                    height: nil,
                    temperature: temperature,
                    dewPoint: dewPoint,
                    windDirection: response.hourly?.windDirection[date]?[pressure],
                    windSpeed: response.hourly?.windSpeed[date]?[pressure]
                        .convertToKnots(from: response.hourlyUnits?.windSpeed?[pressure])
                )
            }
            
            let surfaceDataPoint: SoundingData.Point?
            
            if let surfacePressure = response.hourly?.surfacePressure[date], dataPoints.count > 0 {
                surfaceDataPoint = dataPoints
                    .reduce(dataPoints.first!) {
                        abs($1.pressure - surfacePressure) < abs($0.pressure - surfacePressure) ? $1 : $0
                    }
            } else {
                surfaceDataPoint = nil
            }

            data[date] = SoundingData(
                time: date,
                elevation: response.elevation,
                dataPoints: dataPoints,
                surfaceDataPoint: surfaceDataPoint,
                cape: response.hourly?.cape?[date],
                cin: response.hourly?.cin?[date],
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
            let surfacePressure: SurfacePressureUnit?
            
            let temperature: [Int: TemperatureUnit]?
            let dewPoint: [Int: TemperatureUnit]?
            let windSpeed: [Int: WindSpeedUnit]?
            let windDirection: [Int: WindDirectionUnit]?
            
            let cape: CapeUnit?
            let cin: CinUnit?
            
            let allPressures: Set<Int>
            
            enum TimeUnit: String, Decodable, CaseIterable {
                case iso8601 = "iso8601"
                case unixTime = "unixtime"
            }
            
            enum TemperatureUnit: String, Decodable {
                case celsius = "°C"
                case fahrenheit = "°F"
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
            
            enum CapeUnit: String, Decodable {
                case jkg = "J/kg"
            }
            
            enum CinUnit: String, Decodable {
                case jkg = "J/kg"
            }
            
            enum SurfacePressureUnit: String, Decodable {
                case hpa = "hPa"
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
                surfacePressure = try? container.decode(SurfacePressureUnit.self, forKey: HourlyUnitKey(stringValue: "surfacePressure"))
                cape = try? container.decode(CapeUnit.self, forKey: HourlyUnitKey(stringValue:"cape"))
                cin = try? container.decode(CinUnit.self, forKey: HourlyUnitKey(stringValue: "cin"))
                
                var temperature: [Int: TemperatureUnit] = [:]
                var dewPoint: [Int: TemperatureUnit] = [:]
                var windSpeed: [Int: WindSpeedUnit] = [:]
                var windDirection: [Int: WindDirectionUnit] = [:]
                var allPressures = Set<Int>()
                
                try container.allKeys.forEach { key in
                    let r = /([A-Za-z]+)(\d+0)Hpa/
                    
                    guard let match = key.stringValue.firstMatch(of: r), let pressure = Int(match.output.2) else {
                        return
                    }
                    
                    allPressures.insert(pressure)
                    let keyName = String(match.output.1)
                    
                    switch keyName {
                    case "temperature":
                        temperature[pressure] = try container.decode(TemperatureUnit.self, forKey: key)
                    case "dewPoint":
                        dewPoint[pressure] = try container.decode(TemperatureUnit.self, forKey: key)
                    case "windSpeed":
                        windSpeed[pressure] = try container.decode(WindSpeedUnit.self, forKey: key)
                    case "windDirection":
                        windDirection[pressure] = try container.decode(WindDirectionUnit.self, forKey: key)
                    default:
                        return
                    }
                }
                
                self.temperature = temperature
                self.dewPoint = dewPoint
                self.windSpeed = windSpeed
                self.windDirection = windDirection
                self.allPressures = allPressures
            }
        }
        
        struct HourlyData: DecodableWithConfiguration {
            init(from decoder: any Decoder, configuration: HourlyUnits?) throws {
                let container = try decoder.container(keyedBy: HourlyDataKey.self)
                
                var times: [Date]
                var surfacePressure: [Date: Double] = [:]
                var temperature: [Date: [Int: Double]] = [:]
                var dewPoint: [Date: [Int: Double]] = [:]
                var windSpeed: [Date: [Int: Double]] = [:]
                var windDirection: [Date: [Int: Int]] = [:]
                var cape: [Date: Int] = [:]
                var cin: [Date: Int] = [:]
                
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
                
                if let pressures = try? container.decode([Double].self, forKey: HourlyDataKey(stringValue: "surfacePressure")) {
                    for (i, pressure) in pressures.enumerated() {
                        surfacePressure[times[i]] = pressure
                    }
                }
                
                if let capeList = try? container.decode([Int].self, forKey: HourlyDataKey(stringValue: "cape")) {
                    for (i, capeValue) in capeList.enumerated() {
                        cape[times[i]] = capeValue
                    }
                }
                
                if let cinList = try? container.decode([Int].self, forKey: HourlyDataKey(stringValue: "cin")) {
                    for (i, cinValue) in cinList.enumerated() {
                        cin[times[i]] = cinValue
                    }
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
                    case "dewPoint":
                        for (dateIndex, dewPointThisPressure) in try container.decode([Double].self, forKey: key).enumerated() {
                            if dewPoint[times[dateIndex]] == nil {
                                dewPoint[times[dateIndex]] = [:]
                            }

                            dewPoint[times[dateIndex]]![pressure] = dewPointThisPressure
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
                self.surfacePressure = surfacePressure
                self.temperature = temperature
                self.dewPoint = dewPoint
                self.windSpeed = windSpeed
                self.windDirection = windDirection
                self.cape = cape
                self.cin = cin
            }
            
            typealias DecodingConfiguration = HourlyUnits?
            
            let times: [Date]
            let surfacePressure: [Date: Double]
            
            // Values keyed by pressure keyed by timestamp
            let temperature: [Date: [Int: Double]]
            let dewPoint: [Date: [Int: Double]]
            let windSpeed: [Date: [Int: Double]]
            let windDirection: [Date: [Int: Int]]
            
            let cape: [Date: Int]?
            let cin: [Date: Int]?
            
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

extension OpenMeteoSoundingList.OpenMeteoData.HourlyUnits.WindSpeedUnit {
    var multiplierToKnots: Double {
        switch self {
        case .kph:
            return 0.539957
        case .kn:
            return 1.0
        case .mph:
            return 0.868976
        case .ms:
            return 1.94384
        }
    }
}

extension Double? {
    func convertToKnots(from originalType: OpenMeteoSoundingList.OpenMeteoData.HourlyUnits.WindSpeedUnit?) -> Double? {
        guard let v = self else {
            return nil
        }
        
        return v * (originalType?.multiplierToKnots ?? 1.0)
    }
}

extension OpenMeteoSoundingList.OpenMeteoData.HourlyUnits.TemperatureUnit? {
    var unit: Skewt.TemperatureUnit {
        switch self {
        case .fahrenheit:
            return .fahrenheit
        case .celsius:
            return .celsius
        case .none:
            return .celsius
        }
    }
}

extension Double? {
    func convertToCelsius(from originalType: OpenMeteoSoundingList.OpenMeteoData.HourlyUnits.TemperatureUnit?) -> Double? {
        guard let v = self else {
            return nil
        }
        
        return Temperature(v, unit: originalType.unit).value(inUnit: .celsius)
    }
}
