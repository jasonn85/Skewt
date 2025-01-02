//
//  OpenMeteoTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 11/6/24.
//

import Testing
import Foundation
@testable import Skewt

class OpenMeteoTests {
    @Test("24 results (UTC timestamps) parse into 24 soundings")
    func parseMultipleSoundings() throws {
        let bundle = Bundle(for: OpenMeteoTests.self)
        let fileUrl = bundle.url(forResource: "open-meteo", withExtension: "json")!
        let data = try Data(contentsOf: fileUrl)
        
        let result = try OpenMeteoSoundingList(fromData: data)
        #expect(result.data.count == 24)
    }
    
    @Test("24 results with some null values parse into 24 soundings")
    func parseWithNulls() throws {
        let bundle = Bundle(for: OpenMeteoTests.self)
        let fileUrl = bundle.url(forResource: "open-meteo-with-nulls", withExtension: "json")!
        let data = try Data(contentsOf: fileUrl)
        
        let result = try OpenMeteoSoundingList(fromData: data)
        #expect(result.data.count == 24)
    }
    
    @Test("Parses all Open-Meteo date formats",
          arguments: OpenMeteoSoundingList.OpenMeteoData.HourlyUnits.TimeUnit.allCases)
    func dateFormats(timeUnit: OpenMeteoSoundingList.OpenMeteoData.HourlyUnits.TimeUnit) throws {
        let date = Date(timeIntervalSince1970: 1731089721)
        var dateString: String
        
        switch timeUnit {
        case .iso8601:
            let dateFormatter = ISO8601DateFormatter()
            dateString = "\"\(dateFormatter.string(from: date))\""
        case .unixTime:
            dateString = String(Int(date.timeIntervalSince1970))
        }
        
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"\(timeUnit.rawValue)",
        "temperature_1000hPa":"°C"
    },
    "hourly":{
        "time":[
            \(dateString)
        ],
        "temperature_1000hPa":[
            3.0
        ]
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)
        
        #expect(result.data.values.first?.time == date)
    }
    
    @Test("Parses temperature units correctly, resulting in celsius")
    func temperatureUnits() throws {
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"unixtime",
        "temperature_1000hPa":"°C",
        "temperature_900hPa": "°F",
        "temperature_800hPa":"°C",
        "temperature_700hPa": "°F"
    },
    "hourly":{
        "time":[1731089721],
        "temperature_1000hPa":[0.0],
        "temperature_900hPa":[32.0],
        "temperature_800hPa":[0.0],
        "temperature_700hPa":[32.0]
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)

        result.data.values.first?.dataPoints.forEach {
            #expect($0.temperature == 0.0)
        }
    }
    
    @Test("Parses dew point units correctly, resulting in celsius")
    func dewPointUnits() throws {
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"unixtime",
        "dew_point_1000hPa":"°C",
        "dew_point_900hPa": "°F",
        "dew_point_800hPa":"°C",
        "dew_point_700hPa": "°F"
    },
    "hourly":{
        "time":[1731089721],
        "dew_point_1000hPa":[0.0],
        "dew_point_900hPa":[32.0],
        "dew_point_800hPa":[0.0],
        "dew_point_700hPa":[32.0]
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)

        result.data.values.first?.dataPoints.forEach {
            #expect($0.dewPoint == 0.0)
        }
    }
    
    @Test("Parses wind units correctly, resulting in knots")
    func windUnits() throws {
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"unixtime",
        "wind_speed_1000hPa":"kn",
        "wind_speed_900hPa":"km/h",
        "wind_speed_800hPa":"m/s",
        "wind_speed_700hPa":"mp/h"

    },
    "hourly":{
        "time":[1731089721],
        "wind_speed_1000hPa":[100.0],
        "wind_speed_900hPa":[185.2],
        "wind_speed_800hPa":[51.44],
        "wind_speed_700hPa":[115.08]
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)

        result.data.values.first?.dataPoints.forEach {
            #expect(abs($0.windSpeed! - 100.0) < 0.01)
        }
    }
    
    @Test("Surface pressure is parsed")
    func surfacePressure() throws {
        let count = 10
        
        // Hour by hour
        let dates = stride(from: 0, to: count, by: 1).map {
            Date(timeIntervalSince1970: 1731455336.0 + (Double($0) * 60.0 * 60.0))
        }
        
        // 1000, 950, 900, etc. for pressures
        let pressures = stride(from: 0, to: count, by: 1).map {
            1000.0 - (Double($0) * 50.0)
        }
        
        let temperatures = stride(from: 0, to: count, by: 1).map {
            15.0 - Double($0)
        }
        
        let jsonArrayOfTemperatures = "[\(temperatures.map { String($0) }.joined(separator: ","))]"
        
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"unixtime",
        "surface_pressure":"hPa",
        \(pressures.map({"\"temperature_\(String(Int($0)))hPa\":\"°C\""}).joined(separator: ",\n"))
    },
    "hourly":{
        "time":[
            \(dates.map({ String(Int($0.timeIntervalSince1970)) }).joined(separator: ","))
        ],
        "surface_pressure":[
            \(pressures.map({ String($0) }).joined(separator: ","))
        ],
        \(pressures.map({"\"temperature_\(String(Int($0)))hPa\": \(jsonArrayOfTemperatures)"}).joined(separator: ",\n"))
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)
        
        for i in 0..<count {
            #expect(result.data[dates[i]]?.surfaceDataPoint?.pressure == pressures[i])
        }
    }
    
    @Test("CAPE is processed",
          arguments: [
            [0],
            [0, 1000, 2000, 3000],
            [25, 7555, 9999, 0]
          ]
    )
    func cape(values: [Int]) throws {
        let dates = values.indices.map { Date(timeIntervalSince1970: 1731528361).addingTimeInterval(Double($0) * 60.0 * 60.0) }
        
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"unixtime",
        "temperature_1000hPa":"°C",
        "cape":"J/kg"
    },
    "hourly":{
        "time":[
            \(dates.map({ String(Int($0.timeIntervalSince1970)) }).joined(separator:","))
        ],
        "cape":[
            \(values.map({ String($0) }).joined(separator:","))
        ],
        "temperature_1000hPa":[
            \(values.map({ _ in return "15.0" }).joined(separator:","))
        ]   
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)

        for i in 0..<values.count {
            #expect(result.data[dates[i]]?.cape == values[i])
        }
    }
    
    @Test("CIN is processed",
          arguments: [
            [0],
            [0, 10, 77, 155],
            [25, 225]
          ]
    )
    func cin(values: [Int]) throws {
        let dates = values.indices.map { Date(timeIntervalSince1970: 1731528361).addingTimeInterval(Double($0) * 60.0 * 60.0) }
        
        let json = """
{
    "latitude":52.52, "longitude":13.41, "utc_offset_seconds":0, "timezone":"GMT", "timezone_abbreviation":"GMT", "elevation":38.0,
    "hourly_units":{
        "time":"unixtime",
        "temperature_1000hPa":"°C",
        "cin":"J/kg"
    },
    "hourly":{
        "time":[
            \(dates.map({ String(Int($0.timeIntervalSince1970)) }).joined(separator:","))
        ],
        "cin":[
            \(values.map({ String($0) }).joined(separator:","))
        ],
        "temperature_1000hPa":[
            \(values.map({ _ in return "15.0" }).joined(separator:","))
        ]   
    }
}
"""
        
        let result = try OpenMeteoSoundingList(fromData: json.data(using: .utf8)!)

        for i in 0..<values.count {
            #expect(result.data[dates[i]]?.cin == values[i])
        }
    }
}
