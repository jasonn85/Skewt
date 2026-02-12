//
//  NCAFSoundingMessage.swift
//  Skewt
//
//  Created by Jason Neel on 2/9/26.
//

import Foundation

struct NCAFSoundingMessage {
    let time: DateComponents
    let type: MessageType
    let stationId: Int
    let windUnit: WindUnit
    let lowestPressure: Int?  // TODO: Decide if this is misnamed or not needed at all
    
    enum WindUnit {
        case ms
        case knots
    }
    
    enum MessageType: String {
        case partA = "TTAA"
        case partB = "TTBB"
        case partC = "TTCC"
        case partD = "TTDD"
    }
    
    enum LevelType {
        case surface
        case tropopause(Double)
        case pressure(Double)
        case altitude(Int)
    }
    
    struct Level {
        let type: LevelType
        
        let pressureGroup: PressureGroup?
        let temperatureGroup: TemperatureGroup?
        let windGroup: WindGroup?
    }
    
    struct PressureGroup {
        let isSurface: Bool
        let pressure: Double
        let height: Int?
    }
    
    struct TemperatureGroup {
        let temperature: Double?
        let dewPoint: Double?
    }
    
    struct WindGroup {
        let direction: Int?
        let speed: Int?
    }
}

extension NCAFSoundingMessage {
    init?(fromString s: String) {
        let groups = s
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard var i = groups.firstIndex(where: { MessageType(rawValue: $0) != nil }) else {
            return nil
        }
        
        var levels: [Level] = []
                
        // MARK: - Section 1
        let section1 = groups[i..<(i + 3)]
        i = section1.endIndex
        
        let typeGroup = section1.first!
        let timestampGroup = section1.dropFirst().first!
        let stationIdGroup = section1.last!
        
        if stationIdGroup == "NIL" || timestampGroup == "/////" {
            return nil
        }
        
        guard let type = MessageType(rawValue: typeGroup),
              let rawDay = Int(timestampGroup.prefix(2)),
              let hour = Int(timestampGroup.dropFirst(2).prefix(2)),
              let stationId = Int(stationIdGroup) else {
            return nil
        }
        
        if let lowestPressure = Int(timestampGroup.suffix(1)) {
            self.lowestPressure = lowestPressure * 100
        } else {
            self.lowestPressure = nil
        }
        
        self.type = type
        self.stationId = stationId
        let day: Int
        
        if rawDay >= 50 {
            self.windUnit = .knots
            day = rawDay - 50
        } else {
            self.windUnit = .ms
            day = rawDay
        }
        
        var date = DateComponents()
        date.calendar = Calendar(identifier: .gregorian)
        date.timeZone = .gmt
        date.day = day
        date.hour = hour
        
        self.time = date
                
        // MARK: - Section 2
        if type == .partA || type == .partC {
            let section2Terminators = ["88", "77", "31313", "51515"]
            let endOfSection2 = groups[i...].firstIndex { group in
                section2Terminators.contains { group.hasPrefix($0) }
            } ?? groups[i...].endIndex
            
            let section2 = groups[i..<endOfSection2]
            i = endOfSection2
            
            stride(from: section2.startIndex, to: section2.endIndex - 2, by: 3).forEach {
                guard let pressureGroup = PressureGroup(fromString: section2[$0]) else {
                    return
                }
                
                let temperatureGroup = TemperatureGroup(fromString: section2[$0 + 1])
                let windGroup = WindGroup(fromString: section2[$0 + 2])
                                
                let level = Level(
                    type: pressureGroup.isSurface ? .surface : .pressure(pressureGroup.pressure),
                    pressureGroup: pressureGroup,
                    temperatureGroup: temperatureGroup,
                    windGroup: windGroup
                )
                
                levels.append(level)
            }
        }
        
        // MARK: - Section 3
        if groups[i...].first?.prefix(2) == "88" {
            let section3Terminators = ["88", "77", "31313", "51515"]
            let endOfSection3 = groups[i...].firstIndex { group in
                section3Terminators.contains { group.hasPrefix($0) }
            } ?? groups[i...].endIndex
            
            let section3 = groups[i..<endOfSection3]
            i = endOfSection3
            
            guard section3.count >= 3,
                  let tropopauseGroup = PressureGroup(fromTropopauseString: section3.first!),
                  let temperatureGroup = TemperatureGroup(fromString: section3.dropFirst().first!),
                  let windGroup = WindGroup(fromString: section3.last!) else {
                return nil
            }
            
            let tropopauseLevel = Level(
                type: .tropopause(tropopauseGroup.pressure),
                pressureGroup: tropopauseGroup,
                temperatureGroup: temperatureGroup,
                windGroup: windGroup
            )
            
            levels.append(tropopauseLevel)
        }
    }
}

extension NCAFSoundingMessage.PressureGroup {
    init?(fromTropopauseString s: String) {
        guard s.prefix(2) == "88", let ppp = Int(s.suffix(3)) else {
            return nil
        }
        
        self.isSurface = false
        self.pressure = Double(ppp)
        self.height = nil
    }
    
    init?(fromString s: String) {
        guard let pp = Int(s.prefix(2)) else {
            return nil
        }
        
        let hhhString = s.suffix(3)
        let hhh = Int(hhhString)
                
        if pp == 99 {
            guard let hhh = hhh else {
                return nil
            }
            
            self.isSurface = true
            self.pressure = Double(1000 + hhh)
            self.height = nil
        } else {
            self.isSurface = false
            
            switch pp {
            case 0:
                self.pressure = 1000
            case 92:
                self.pressure = 925
            default:
                self.pressure = Double(pp * 10)
            }
            
            if hhhString == "///" {
                self.height = nil
            } else {
                guard let hhh = hhh else {
                    return nil
                }
                
                // Some ugly height-guessing. It's up to us to divine these adjustments.
                if self.pressure == 1000 || self.pressure == 925 {
                    self.height = hhh
                } else if self.pressure == 850 {
                    self.height = 1000 + hhh
                } else if self.pressure == 700 {
                    self.height = 3000 + hhh
                } else if self.pressure == 500 {
                    self.height = hhh * 10
                } else if self.pressure >= 100 && self.pressure < 500 {
                    let thousands = hhh / 100
                    let decameters = hhh % 100
                    let baseHeight = thousands * 1000 + decameters * 10
                    
                    if self.pressure <= 250 {
                        self.height = 10000 + baseHeight
                    } else {
                        self.height = baseHeight
                    }
                } else {
                    self.height = hhh
                }
            }
        }
    }
}

extension NCAFSoundingMessage.TemperatureGroup {
    init?(fromString s: String) {
        if s == "/////" {
            self.temperature = nil
            self.dewPoint = nil
            return
        }
        
        guard let ttt = Int(s.prefix(3)) else {
            return nil
        }
        
        let sign = (ttt % 2) == 0 ? 1 : -1
        self.temperature = Double(ttt * sign) * 0.1

        let dpdString = s.suffix(2)
        
        if dpdString == "//" {
            self.dewPoint = nil
        } else {
            guard let rawDpd = Int(dpdString) else {
                return nil
            }
            
            let dewPointDepression = rawDpd <= 50 ? Double(rawDpd) * 0.1 : Double(rawDpd - 50)
            self.dewPoint = self.temperature! - dewPointDepression
        }
    }
}

extension NCAFSoundingMessage.WindGroup {
    init?(fromString s: String) {
        if s == "/////" {
            self.direction = nil
            self.speed = nil
            return
        }
        
        guard let rawDirection = Int(s.prefix(3)),
              let rawSpeed = Int(s.suffix(2)) else {
            return nil
        }
        
        let extraHundreds = rawDirection % 5
        self.direction = rawDirection - extraHundreds
        self.speed = rawSpeed + (extraHundreds * 100)
    }
}
