//
//  SoundingTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 7/26/23.
//

import SwiftUI
import CoreLocation

struct SoundingTimeSelectView: View {
    @Binding var value: SoundingSelection.Time
    var hourInterval = SoundingSelection.ModelType.sounding.hourInterval
    let daysRange = 4
    var date: Date = .now
    @State var location: CLLocation? = nil  // Location for showing proper sunrise/sunset times
    
    private var intervals: [TimeInterval]
    
    @GestureState private var dragging = false
    
    init(value: Binding<SoundingSelection.Time>, hourInterval: Int = SoundingSelection.ModelType.sounding.hourInterval, date: Date = .now) {
        _value = value
        self.hourInterval = hourInterval
        self.date = date

        let soundingInterval = TimeInterval(Double(hourInterval) * 60.0 * 60.0)
        let startDate = Date(timeIntervalSinceNow: -Double(daysRange) * 24.0 * 60.0 * 60.0)
        let mostRecentDate = Date.mostRecentSoundingTime()

        let mostRecentIntervalFromNow = mostRecentDate.timeIntervalSinceNow
        let startIntervalFromNow = startDate.timeIntervalSinceNow

        intervals = Array(stride(from: mostRecentIntervalFromNow, through: startIntervalFromNow, by: -soundingInterval))
    }
    
    private var gmtTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = .gmt
        formatter.dateFormat = "EEEE HH:mm'Z'"
        return formatter
    }

    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }

    private var gmtCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }
    
    private var intervalIndex: Int {
        switch value {
        case .now:
            return 0
        case .numberOfSoundingsAgo(let soundingIndex):
            return soundingIndex - 1
        default:
            return 0
        }
    }
    
    private var maxIndex: Int {
        max(intervals.count - 1, 0)
    }
    
    private func indexAsPercentage(_ index: Int) -> Double {
        guard maxIndex > 0 else {
            return 0.0
        }
        
        let normalized = min(max(Double(index) / Double(maxIndex), 0.0), 1.0)
        return 1.0 - normalized
    }
    
    private var valueAsPercentage: Double {
        indexAsPercentage(intervalIndex)
    }

    private var timeRange: ClosedRange<Date> {
        let startDate = Date(timeIntervalSinceNow: -Double(daysRange) * 24.0 * 60.0 * 60.0)
        let endDate = Date.mostRecentSoundingTime(toDate: date)
        
        return startDate...endDate
    }

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 12.0)
            
            HStack {
                Button(action: { incrementValue(by: 1) }, label: {
                    Image(systemName: "minus.circle")
                })
                
                ZStack {
                    GeometryReader { geometry in
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(height: 4)
                            .overlay {
                                GeometryReader { geometry in
                                    let circleSize = dragging ? 18.0 : 12.0
                                    
                                    Circle()
                                        .stroke(.foreground, lineWidth: 1.0)
                                        .fill(.background.opacity(dragging ? 0.66 : 1.0))
                                        .position(x: valueAsPercentage * geometry.size.width, y: geometry.size.height / 2.0)
                                        .frame(width: circleSize, height: circleSize)
                                }
                            }
                            .background {
                                GeometryReader { geometry in
                                    let range = timeRange
                                    
                                    ZStack {
                                        LinearGradient.horizontalSunGradient(
                                            inTimeRange: range,
                                            at: location ?? .equatorialLocation()
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                        
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(.black.opacity(0.08))
                                        
                                        ForEach(tickIndices, id: \.self) { index in
                                            Rectangle()
                                                .fill(.black.opacity(0.4))
                                                .frame(width: 2.0, height: 8.0)
                                                .position(
                                                    x: indexAsPercentage(index) * geometry.size.width,
                                                    y: geometry.size.height / 2.0
                                                )
                                        }
                                    }
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0.0)
                                    .updating($dragging) { _, state, _ in
                                        state = true
                                    }
                                    .onChanged { value in
                                        setValue(toX: value.location.x / geometry.size.width)
                                    }
                            )
                    }
                    .frame(height: 4)
                }
                
                Button(action: { incrementValue(by: -1) }, label: {
                    Image(systemName: "plus.circle")
                })
            }
            .scenePadding(.horizontal)
            
            Text(valueDescription)
                .font(.system(size: 12.0))
                .opacity(dragging ? 1.0 : 0.0)
            
            Text(valueRelativeDescription)
                .font(.system(size: 11.0))
                .opacity(0.7)
                .opacity(dragging ? 1.0 : 0.0)
        }
    }
    
    private var valueDescription: String {
        guard !intervals.isEmpty else {
            return "Now"
        }
        
        let clampedIndex = min(max(intervalIndex, 0), maxIndex)
        let date = Date(timeIntervalSinceNow: intervals[clampedIndex])
        
        return gmtTimeFormatter.string(from: date)
    }

    private var valueRelativeDescription: String {
        guard !intervals.isEmpty else {
            return "Now"
        }
        
        let clampedIndex = min(max(intervalIndex, 0), maxIndex)
        let interval = intervals[clampedIndex]
        
        return relativeFormatter.localizedString(fromTimeInterval: interval)
    }

    private var tickIndices: [Int] {
        intervals.enumerated().compactMap { index, interval in
            let date = Date(timeIntervalSinceNow: interval)
            let hour = gmtCalendar.component(.hour, from: date)
            return (hour == 0 || hour == 12) ? index : nil
        }
    }
    
    private func incrementValue(by step: Int) {
        guard !intervals.isEmpty else {
            value = .now
            return
        }
        
        let newIndex = min(max(intervalIndex + step, 0), maxIndex)
        setValue(toIndex: newIndex)
    }
    
    private func setValue(toX x: CGFloat) {
        guard maxIndex > 0 else {
            value = .now
            return
        }
        
        let clamped = min(max(x, 0.0), 1.0)
        let index = Int(round((1.0 - clamped) * Double(maxIndex)))
        
        setValue(toIndex: index)
    }
    
    private func setValue(toIndex index: Int) {
        if index == 0 {
            value = .now
        } else {
            value = .numberOfSoundingsAgo(index + 1)
        }
    }
}

struct SoundingTimeSelectView_Previews: PreviewProvider {
    private struct PreviewWrapper: View {
        @State private var time = SoundingSelection.Time.now
        
        var body: some View {
            SoundingTimeSelectView(value: $time)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
