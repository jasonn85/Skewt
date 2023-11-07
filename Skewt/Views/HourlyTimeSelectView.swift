//
//  HourlyTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 5/23/23.
//

import SwiftUI
import CoreLocation

struct HourlyTimeSelectView: View {
    @Binding var value: SoundingSelection.Time
    @State var range: ClosedRange<TimeInterval>
    @State var stepSize: TimeInterval = .hours(1)
    @State var location: CLLocation? = nil  // Location for showing proper sunrise/sunset times
    
    @State private var dragging = false
    
    private func timeIntervalAsPercentage(_ interval: TimeInterval) -> Double {
        let rawPercentage = (interval - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        return min(max(rawPercentage, 0.0), 1.0)
    }
    
    private var valueAsPercentage: Double {
        switch value {
        case .now:
            return 0.5
        case .numberOfSoundingsAgo(_):
            // Not supported by this time selection UI
            return 0.5
        case .specific(let date):
            return timeIntervalAsPercentage(date.timeIntervalSinceNow)
        case .relative(let interval):
            return timeIntervalAsPercentage(interval)
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 12.0)
            
            HStack {
                Button(action: { incrementValue(by: -stepSize) }, label: {
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
                                    let start = Date(timeIntervalSinceNow: range.lowerBound)
                                    let end = Date(timeIntervalSinceNow: range.upperBound)
                                    
                                    ZStack {
                                        LinearGradient.horizontalSunGradient(
                                            inTimeRange: start...end,
                                            at: location ?? .equatorialLocationForCurrentTimeZone
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                        
                                        Rectangle()
                                            .fill(.yellow)
                                            .frame(width: 2.0, height: geometry.size.height)
                                            .position(
                                                x: timeIntervalAsPercentage(0.0) * geometry.size.width,
                                                y: geometry.size.height / 2.0
                                            )
                                    }
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0.0)
                                    .onChanged { value in
                                        dragging = true
                                        
                                        setValue(toX: value.location.x / geometry.size.width)
                                    }
                                    .onEnded { _ in
                                        dragging = false
                                    }
                            )
                    }
                    .frame(height: 4)
                }
                
                Button(action: { incrementValue(by: stepSize) }, label: {
                    Image(systemName: "plus.circle")
                })
            }
            .scenePadding(.horizontal)
            
            Text(valueDescription)
                .font(.system(size: 12.0))
                .opacity(dragging ? 1.0 : 0.0)
        }
    }
    
    private func incrementValue(by d: TimeInterval) {
        switch value {
        case .numberOfSoundingsAgo(_):
            return  // not supported
        case .relative(let interval):
            setValue(toRelativeTimeInterval: interval + d)
        case .now:
            setValue(toRelativeTimeInterval: d)
        case .specific(let date):
            setValue(toRelativeTimeInterval: date.addingTimeInterval(d).timeIntervalSinceNow)
        }
    }
    
    private var shortTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        return formatter
    }
    
    private var valueDescription: String {
        switch value {
        case .numberOfSoundingsAgo(let count):
            return "\(count) soundings ago"
        case .specific(let date):
            return shortTimeFormatter.string(from: date)
        case .relative(let interval):
            let date = Date.nearestHour(
                withIntervalFromNow: interval,
                hoursPerInterval: Int(stepSize / 3_600.0)
            )
            
            return shortTimeFormatter.string(from: date)
        case .now:
            return "Now"
        }
    }
    
    private func setValue(toX x: CGFloat) {
        let x = min(max(x, 0.0), 1.0)
        let exactValue = x * (range.upperBound - range.lowerBound) + range.lowerBound
        let newValue = round(exactValue / stepSize) * stepSize
        
        setValue(toRelativeTimeInterval: newValue)
    }
    
    private func setValue(toRelativeTimeInterval interval: TimeInterval) {
        if interval == 0.0 {
            value = .now
        } else {
            value = .relative(interval)
        }
    }
}

extension SunState {
    func colors(withTransitionTime transition: TimeInterval) -> [(Date, Color)] {
        switch type {
        case .day:
            return [(date, Color("BasicDaylight", bundle: nil))]
        case .night:
            return [(date, Color("BasicNight", bundle: nil))]
        case .sunrise:
            return [
                (date.addingTimeInterval(-transition), Color("BasicNight", bundle: nil)),
                (date.addingTimeInterval(transition), Color("BasicDaylight", bundle: nil))
            ]
        case .sunset:
            return [
                (date.addingTimeInterval(-transition), Color("BasicDaylight", bundle: nil)),
                (date.addingTimeInterval(transition), Color("BasicNight", bundle: nil))
            ]
        }
    }
}

extension LinearGradient {
    static func horizontalSunGradient(inTimeRange range: ClosedRange<Date>, at location: CLLocation) -> LinearGradient {
        let states = SunState.states(inRange: range, at: location)
        let dateRange = range.upperBound.timeIntervalSince(range.lowerBound)
        let transition = TimeInterval(60.0 * 60.0)  // 60 minutes
        
        let stops = states.flatMap { $0.colors(withTransitionTime: transition) }
            .sorted(by: { $0.0 < $1.0 })
            .map {
                Gradient.Stop(color: $0.1, location: $0.0.timeIntervalSince(range.lowerBound) / dateRange)
            }
        
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}

extension SoundingSelection.Time {
    public var asInterval: TimeInterval {
        switch self {
        case .now:
            return 0.0
        case .relative(let interval):
            return interval
        case .specific(let date):
            return Date.now.timeIntervalSince(date)
        case .numberOfSoundingsAgo(_):
            return 0.0
        }
    }
}

extension TimeInterval {
    static func hours(_ hours: Int) -> TimeInterval {
        Double(hours) * 60.0 * 60.0
    }
}

struct TimeSelectView_Previews: PreviewProvider {
    static var previews: some View {
        var time = SoundingSelection.Time.now

        HourlyTimeSelectView(
            value: Binding<SoundingSelection.Time>(get: { time }, set: { time = $0 }),
            range: .hours(-24)...TimeInterval.hours(24)
        )
    }
}
