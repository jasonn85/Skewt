//
//  OpenMeteoRequestTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 11/17/24.
//

import Testing
import Foundation
@testable import Skewt

struct OpenMeteoRequestTests {
    @Test("URL resolves")
    func someUrl() {
        #expect(OpenMeteoSoundingListRequest.apiUrl.absoluteString.count > 0)
    }
    
    @Test("All temperatures/dew points/wind speeds/wind directions show up in query parameters")
    func requestAllHourly() {
        let allSkewt = OpenMeteoSoundingListRequest.HourlyValue.allTemperatures
            + OpenMeteoSoundingListRequest.HourlyValue.allDewPoints
            + OpenMeteoSoundingListRequest.HourlyValue.allWindSpeeds
            + OpenMeteoSoundingListRequest.HourlyValue.allWindDirections
        
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            hourly: allSkewt
        )
        
        let hourlyItem = request.queryItems!.filter({ $0.name == "hourly" }).first!
        let hourlyValues = hourlyItem.value!.split(separator: ",").map { String($0) }
        
        allSkewt.forEach {
            #expect(hourlyValues.contains($0.rawValue))
        }
    }
    
    @Test("Temperature unit is sent", arguments: OpenMeteoSoundingListRequest.TemperatureUnit.allCases)
    func temperatureUnit(unit: OpenMeteoSoundingListRequest.TemperatureUnit) {
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            temperature_unit: unit
        )
                
        #expect(request.queryItems!.filter({ $0.name == "temperature_unit" }).first!.value! == unit.rawValue)
    }
    
    @Test("Wind speed unit is sent", arguments: OpenMeteoSoundingListRequest.WindSpeedUnit.allCases)
    func windUnit(unit: OpenMeteoSoundingListRequest.WindSpeedUnit) {
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            wind_speed_unit: unit
        )
                
        #expect(request.queryItems!.filter({ $0.name == "wind_speed_unit" }).first!.value! == unit.rawValue)
    }
    
    @Test("Precipitation unit is sent", arguments: OpenMeteoSoundingListRequest.PrecipitationUnit.allCases)
    func precipUnit(unit: OpenMeteoSoundingListRequest.PrecipitationUnit) {
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            precipitation_unit: unit
        )
                
        #expect(request.queryItems!.filter({ $0.name == "precipitation_unit" }).first!.value! == unit.rawValue)
    }
    
    @Test("Time format is sent", arguments: OpenMeteoSoundingListRequest.TimeFormat.allCases)
    func timeFormat(unit: OpenMeteoSoundingListRequest.TimeFormat) {
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            timeformat: unit
        )
                
        #expect(request.queryItems!.filter({ $0.name == "timeformat" }).first!.value! == unit.rawValue)
    }
    
    @Test("API key is sent if specified")
    func goodApiKey() {
        let key = "yabbadabbadoo"
        
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            apikey: key
        )
        
        #expect(request.queryItems!.filter({ $0.name == "apikey" }).first!.value! == key)
    }
    
    @Test("No value for API key is sent if none is specified")
    func noApiKey() {
        let request = OpenMeteoSoundingListRequest(latitude: 39.7392, longitude: -104.9903)
        
        #expect(request.queryItems!.filter({ $0.name == "apikey" }).isEmpty)
    }
    
    @Test("Start hour/end hour are encoded as yyyy-mm-ddThh:mm")
    func startHourEndHour() {
        let date = Date(timeIntervalSince1970: 1735956408)
        let dateString = "2025-01-04T02:06"
        
        let request = OpenMeteoSoundingListRequest(
            latitude: 39.7392,
            longitude: -104.9903,
            start_hour: date,
            end_hour: date
        )
        
        let encodedStart = request.queryItems!.filter({ $0.name == "start_hour" }).first!.value!
        let encodedEnd = request.queryItems!.filter({ $0.name == "end_hour" }).first!.value!

        #expect(encodedStart == dateString)
        #expect(encodedEnd == dateString)
    }
}
