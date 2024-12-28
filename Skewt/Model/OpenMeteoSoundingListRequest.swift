//
//  OpenMeteoSoundingListRequest.swift
//  Skewt
//
//  Created by Jason Neel on 11/16/24.
//

import Foundation

struct OpenMeteoSoundingListRequest: Codable {
    let latitude: Double
    let longitude: Double
    
    let hourly: [HourlyValue]?
    let daily: [DailyValue]?
    let current: [HourlyValue]?
    
    let temperature_unit: TemperatureUnit?
    let wind_speed_unit: WindSpeedUnit?
    let precipitation_unit: PrecipitationUnit?
    
    let timeformat: TimeFormat?
    let timezone: String?
    
    let past_days: Int?
    let forecast_days: Int?
    let forecast_hours: Int?
    let forecast_minutely_15: Int?
    let past_hours: Int?
    let past_minutely_15: Int?
    
    let start_date: Date?
    let end_date: Date?
    let start_hour: Date?
    let end_hour: Date?
    let start_minutely_15: Date?
    let end_minutely_15: Date?
    
    let models: [Model]?
    
    let apikey: String?
    
    enum HourlyValue: String, Codable {
        case temperature_2m
        case relative_humidity_2m
        case dew_point_2m
        case apparent_temperature
        case pressure_msl
        case surface_pressure
        case cloud_cover
        case cloud_cover_low
        case cloud_cover_mid
        case cloud_cover_high
        case wind_speed_10m
        case wind_speed_80m
        case wind_speed_120m
        case wind_speed_180m
        case wind_direction_10m
        case wind_direction_80m
        case wind_direction_120m
        case wind_direction_180m
        case wind_gusts_10m
        case shortwave_radiation
        case direct_radiation
        case direct_normal_irradiance
        case diffuse_radiation
        case global_tilted_irradiance
        case vapour_pressure_deficit
        case cape
        case evapotranspiration
        case et0_fao_evapotranspiration
        case precipitation
        case snowfall
        case precipitation_probability
        case rain
        case showers
        case weather_code
        case snow_depth
        case freezing_level_height
        case visibility
        case soil_temperature_0cm
        case soil_temperature_6cm
        case soil_temperature_18cm
        case soil_temperature_54cm
        case soil_moisture_0_to_1cm
        case soil_moisture_1_to_3cm
        case soil_moisture_3_to_9cm
        case soil_moisture_9_to_27cm
        case soil_moisture_27_to_81cm
        case is_day
        case temperature_1000hPa
        case temperature_975hPa
        case temperature_950hPa
        case temperature_925hPa
        case temperature_900hPa
        case temperature_850hPa
        case temperature_800hPa
        case temperature_700hPa
        case temperature_600hPa
        case temperature_500hPa
        case temperature_400hPa
        case temperature_300hPa
        case temperature_250hPa
        case temperature_200hPa
        case temperature_150hPa
        case temperature_100hPa
        case temperature_70hPa
        case temperature_50hPa
        case temperature_30hPa
        case relative_humidity_1000hPa
        case relative_humidity_975hPa
        case relative_humidity_950hPa
        case relative_humidity_925hPa
        case relative_humidity_900hPa
        case relative_humidity_850hPa
        case relative_humidity_800hPa
        case relative_humidity_700hPa
        case relative_humidity_600hPa
        case relative_humidity_500hPa
        case relative_humidity_400hPa
        case relative_humidity_300hPa
        case relative_humidity_250hPa
        case relative_humidity_200hPa
        case relative_humidity_150hPa
        case relative_humidity_100hPa
        case relative_humidity_70hPa
        case relative_humidity_50hPa
        case relative_humidity_30hPa
        case dew_point_1000hPa
        case dew_point_975hPa
        case dew_point_950hPa
        case dew_point_925hPa
        case dew_point_900hPa
        case dew_point_850hPa
        case dew_point_800hPa
        case dew_point_700hPa
        case dew_point_600hPa
        case dew_point_500hPa
        case dew_point_400hPa
        case dew_point_300hPa
        case dew_point_250hPa
        case dew_point_200hPa
        case dew_point_150hPa
        case dew_point_100hPa
        case dew_point_70hPa
        case dew_point_50hPa
        case dew_point_30hPa
        case cloud_cover_1000hPa
        case cloud_cover_975hPa
        case cloud_cover_950hPa
        case cloud_cover_925hPa
        case cloud_cover_900hPa
        case cloud_cover_850hPa
        case cloud_cover_800hPa
        case cloud_cover_700hPa
        case cloud_cover_600hPa
        case cloud_cover_500hPa
        case cloud_cover_400hPa
        case cloud_cover_300hPa
        case cloud_cover_250hPa
        case cloud_cover_200hPa
        case cloud_cover_150hPa
        case cloud_cover_100hPa
        case cloud_cover_70hPa
        case cloud_cover_50hPa
        case cloud_cover_30hPa
        case wind_speed_1000hPa
        case wind_speed_975hPa
        case wind_speed_950hPa
        case wind_speed_925hPa
        case wind_speed_900hPa
        case wind_speed_850hPa
        case wind_speed_800hPa
        case wind_speed_700hPa
        case wind_speed_600hPa
        case wind_speed_500hPa
        case wind_speed_400hPa
        case wind_speed_300hPa
        case wind_speed_250hPa
        case wind_speed_200hPa
        case wind_speed_150hPa
        case wind_speed_100hPa
        case wind_speed_70hPa
        case wind_speed_50hPa
        case wind_speed_30hPa
        case wind_direction_1000hPa
        case wind_direction_975hPa
        case wind_direction_950hPa
        case wind_direction_925hPa
        case wind_direction_900hPa
        case wind_direction_850hPa
        case wind_direction_800hPa
        case wind_direction_700hPa
        case wind_direction_600hPa
        case wind_direction_500hPa
        case wind_direction_400hPa
        case wind_direction_300hPa
        case wind_direction_250hPa
        case wind_direction_200hPa
        case wind_direction_150hPa
        case wind_direction_100hPa
        case wind_direction_70hPa
        case wind_direction_50hPa
        case wind_direction_30hPa
        case geopotential_height_1000hPa
        case geopotential_height_975hPa
        case geopotential_height_950hPa
        case geopotential_height_925hPa
        case geopotential_height_900hPa
        case geopotential_height_850hPa
        case geopotential_height_800hPa
        case geopotential_height_700hPa
        case geopotential_height_600hPa
        case geopotential_height_500hPa
        case geopotential_height_400hPa
        case geopotential_height_300hPa
        case geopotential_height_250hPa
        case geopotential_height_200hPa
        case geopotential_height_150hPa
        case geopotential_height_100hPa
        case geopotential_height_70hPa
        case geopotential_height_50hPa
        case geopotential_height_30hPa
    }
    
    enum DailyValue: String, Codable {
        case temperature_2m_max
        case temperature_2m_min
        case apparent_temperature_max
        case apparent_temperature_min
        case precipitation_sum
        case rain_sum
        case showers_sum
        case snowfall_sum
        case precipitation_hours
        case precipitation_probability_max
        case precipitation_probability_min
        case precipitation_probability_mean
        case weather_code
        case sunrise
        case sunset
        case sunshine_duration
        case daylight_duration
        case wind_speed_10m_max
        case wind_gusts_10m_max
        case wind_direction_10m_dominant
        case shortwave_radiation_sum
        case et0_fao_evapotranspiration
        case uv_index_max
        case uv_index_clear_sky_max
    }
    
    enum TemperatureUnit: String, Codable {
        case celsius
        case fahrenheit
    }
    
    enum WindSpeedUnit: String, Codable {
        case kmh
        case ms
        case mph
        case kn
    }
    
    enum PrecipitationUnit: String, Codable {
        case mm
        case inch
    }
    
    enum TimeFormat: String, Codable {
        case iso8601
        case unixtime
    }
    
    enum Model: String, Codable {
        case auto
    }
    
    init(
        latitude: Double,
        longitude: Double,
        hourly: [HourlyValue]? = nil,
        daily: [DailyValue]? = nil,
        current: [HourlyValue]? = nil,
        temperature_unit: TemperatureUnit? = .celsius,
        wind_speed_unit: WindSpeedUnit? = .kn,
        precipitation_unit: PrecipitationUnit? = nil,
        timeformat: TimeFormat? = .unixtime,
        timezone: String? = nil,
        past_days: Int? = nil,
        forecast_days: Int? = nil,
        forecast_hours: Int? = nil,
        forecast_minutely_15: Int? = nil,
        past_hours: Int? = nil,
        past_minutely_15: Int? = nil,
        start_date: Date? = nil,
        end_date: Date? = nil,
        start_hour: Date? = nil,
        end_hour: Date? = nil,
        start_minutely_15: Date? = nil,
        end_minutely_15: Date? = nil,
        models: [Model]? = nil,
        apikey: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.hourly = hourly
        self.daily = daily
        self.current = current
        self.temperature_unit = temperature_unit
        self.wind_speed_unit = wind_speed_unit
        self.precipitation_unit = precipitation_unit
        self.timeformat = timeformat
        self.timezone = timezone
        self.past_days = past_days
        self.forecast_days = forecast_days
        self.forecast_hours = forecast_hours
        self.forecast_minutely_15 = forecast_minutely_15
        self.past_hours = past_hours
        self.past_minutely_15 = past_minutely_15
        self.start_date = start_date
        self.end_date = end_date
        self.start_hour = start_hour
        self.end_hour = end_hour
        self.start_minutely_15 = start_minutely_15
        self.end_minutely_15 = end_minutely_15
        self.models = models
        self.apikey = apikey
    }
}

extension OpenMeteoSoundingListRequest.HourlyValue {
    static var allTemperatures: [OpenMeteoSoundingListRequest.HourlyValue] {
        [
            .temperature_1000hPa, .temperature_975hPa, .temperature_950hPa, .temperature_925hPa,
            .temperature_900hPa, .temperature_850hPa, .temperature_800hPa, .temperature_700hPa,
            .temperature_600hPa, .temperature_500hPa, .temperature_400hPa, .temperature_300hPa,
            .temperature_250hPa, .temperature_200hPa, .temperature_150hPa, .temperature_100hPa,
            .temperature_70hPa, .temperature_50hPa, .temperature_30hPa
        ]
    }
    
    static var allDewPoints: [OpenMeteoSoundingListRequest.HourlyValue] {
        [
            .dew_point_1000hPa, .dew_point_975hPa, .dew_point_950hPa, .dew_point_925hPa,
            .dew_point_900hPa, .dew_point_850hPa, .dew_point_800hPa, .dew_point_700hPa,
            .dew_point_600hPa, .dew_point_500hPa, .dew_point_400hPa, .dew_point_300hPa,
            .dew_point_250hPa, .dew_point_200hPa, .dew_point_150hPa, .dew_point_100hPa,
            .dew_point_70hPa, .dew_point_50hPa, .dew_point_30hPa
        ]
    }
    
    static var allCloudCovers: [OpenMeteoSoundingListRequest.HourlyValue] {
        [
            .cloud_cover_1000hPa, .cloud_cover_975hPa, .cloud_cover_950hPa, .cloud_cover_925hPa,
            .cloud_cover_900hPa, .cloud_cover_850hPa, .cloud_cover_800hPa, .cloud_cover_700hPa,
            .cloud_cover_600hPa, .cloud_cover_500hPa, .cloud_cover_400hPa, .cloud_cover_300hPa,
            .cloud_cover_250hPa, .cloud_cover_200hPa, .cloud_cover_150hPa, .cloud_cover_100hPa,
            .cloud_cover_70hPa, .cloud_cover_50hPa, .cloud_cover_30hPa
        ]
    }
    
    static var allWindSpeeds: [OpenMeteoSoundingListRequest.HourlyValue] {
        [
            .wind_speed_1000hPa, .wind_speed_975hPa, .wind_speed_950hPa, .wind_speed_925hPa,
            .wind_speed_900hPa, .wind_speed_850hPa, .wind_speed_800hPa, .wind_speed_700hPa,
            .wind_speed_600hPa, .wind_speed_500hPa, .wind_speed_400hPa, .wind_speed_300hPa,
            .wind_speed_250hPa, .wind_speed_200hPa, .wind_speed_150hPa, .wind_speed_100hPa,
            .wind_speed_70hPa, .wind_speed_50hPa, .wind_speed_30hPa
        ]
    }
    
    static var allWindDirections: [OpenMeteoSoundingListRequest.HourlyValue] {
        [
            .wind_direction_1000hPa, .wind_direction_975hPa, .wind_direction_950hPa, .wind_direction_925hPa,
            .wind_direction_900hPa, .wind_direction_850hPa, .wind_direction_800hPa, .wind_direction_700hPa,
            .wind_direction_600hPa, .wind_direction_500hPa, .wind_direction_400hPa, .wind_direction_300hPa,
            .wind_direction_250hPa, .wind_direction_200hPa, .wind_direction_150hPa, .wind_direction_100hPa,
            .wind_direction_70hPa, .wind_direction_50hPa, .wind_direction_30hPa
        ]
    }
    
    static var allGeopotentialHeights: [OpenMeteoSoundingListRequest.HourlyValue] {
        [
            .geopotential_height_1000hPa, .geopotential_height_975hPa, .geopotential_height_950hPa,
            .geopotential_height_925hPa, .geopotential_height_900hPa, .geopotential_height_850hPa,
            .geopotential_height_800hPa, .geopotential_height_700hPa, .geopotential_height_600hPa,
            .geopotential_height_500hPa, .geopotential_height_400hPa, .geopotential_height_300hPa,
            .geopotential_height_250hPa, .geopotential_height_200hPa, .geopotential_height_150hPa,
            .geopotential_height_100hPa, .geopotential_height_70hPa, .geopotential_height_50hPa,
            .geopotential_height_30hPa
        ]
    }
}
