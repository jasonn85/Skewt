//
//  UWYCSVSoundingTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 2/16/26.
//

import Testing
import Foundation
@testable import Skewt

struct UWYCSVSoundingTests {
    @Test("Data is loaded from sample CSV data")
    func loadSampleData() throws {
        let bundle = Bundle(for: NCAFSoundingListTestClass.self)
        let fileUrl = bundle.url(forResource: "uwySounding", withExtension: "csv")!
        let data = try Data(contentsOf: fileUrl)
        let string = String(data: data, encoding: .utf8)!
        
        let sounding = UWYSounding(fromCsvString: string)
        
        #expect(sounding != nil)

        guard let sounding else { return }

        // CSV has 6590 data rows (excluding the header).
        #expect(sounding.data.dataPoints.count == 6590)

        // Your parser currently treats the first parsed row as "surface".
        let first = sounding.data.dataPoints.first!
        let last  = sounding.data.dataPoints.last!

        #expect(sounding.data.surfaceDataPoint != nil)
        #expect(sounding.data.surfaceDataPoint?.pressure == first.pressure)

        // Match the date parsing semantics used by your production code (no explicit TZ/locale set).
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.timeZone = .gmt

        let expectedFirstTime = df.date(from: "2026-02-05 23:03:59")
        #expect(first.time == expectedFirstTime)
        #expect(sounding.data.time == expectedFirstTime!)

        // First row in file:
        // 2026-02-05 23:03:59,-108.4767,43.0648, 834.9, 1699, 14.9, -5.4,...,177, 0.4
        #expect(abs(first.longitude! - (-108.4767)) < 1e-6)
        #expect(abs(first.latitude!  - (43.0648))   < 1e-6)

        #expect(abs(first.pressure - 834.9) < 1e-6)
        #expect(abs(first.height! - 1699.0) < 1e-6)
        #expect(abs(first.temperature! - 14.9) < 1e-6)
        #expect(abs(first.dewPoint! - (-5.4)) < 1e-6)
        #expect(first.windDirection == 177)

        // wind speed_m/s = 0.4, converted to knots via * 1.94384
        let expectedFirstWindKt = 0.4 * 1.94384
        #expect(abs(first.windSpeed! - expectedFirstWindKt) < 1e-6)

        // Last row in file:
        // 2026-02-06 00:53:48,-108.1527,42.6286,   5.1,34918,-56.5,-83.7,...,271,29.4
        let expectedLastTime = df.date(from: "2026-02-06 00:53:48")
        #expect(last.time == expectedLastTime)

        #expect(abs(last.longitude! - (-108.1527)) < 1e-6)
        #expect(abs(last.latitude!  - (42.6286))   < 1e-6)

        #expect(abs(last.pressure - 5.1) < 1e-6)
        #expect(abs(last.height! - 34918.0) < 1e-6)
        #expect(abs(last.temperature! - (-56.5)) < 1e-6)
        #expect(abs(last.dewPoint! - (-83.7)) < 1e-6)
        #expect(last.windDirection == 271)

        let expectedLastWindKt = 29.4 * 1.94384
        #expect(abs(last.windSpeed! - expectedLastWindKt) < 1e-6)
    }
}
