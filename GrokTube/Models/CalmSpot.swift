//
//  CalmSpot.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation
import CoreLocation
import MapKit

/// Represents a calm spot in London with all relevant metadata
struct CalmSpot: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let nearestTube: TubeStation
    let imageURL: String? // For remote images
    let systemImage: String // Fallback SF Symbol
    let tags: [String]
    let openingHours: String
    let crowdLevel: CrowdLevel
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CalmSpot, rhs: CalmSpot) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CrowdLevel: String, CaseIterable {
        case quiet = "Quiet"
        case moderate = "Moderate"
        case busy = "Busy"
        
        var color: String {
            switch self {
            case .quiet: return "green"
            case .moderate: return "orange"
            case .busy: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .quiet: return "person"
            case .moderate: return "person.2"
            case .busy: return "person.3"
            }
        }
    }
}

/// Represents a London Underground station
struct TubeStation: Hashable {
    let name: String
    let lines: [TubeLine]
    let coordinate: CLLocationCoordinate2D
    let walkingMinutes: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: TubeStation, rhs: TubeStation) -> Bool {
        lhs.name == rhs.name
    }
}

/// London Underground lines
enum TubeLine: String, CaseIterable {
    case bakerloo = "Bakerloo"
    case central = "Central"
    case circle = "Circle"
    case district = "District"
    case hammersmithCity = "Hammersmith & City"
    case jubilee = "Jubilee"
    case metropolitan = "Metropolitan"
    case northern = "Northern"
    case piccadilly = "Piccadilly"
    case victoria = "Victoria"
    case waterlooCity = "Waterloo & City"
    case dlr = "DLR"
    case elizabeth = "Elizabeth"
    case overground = "Overground"
    
    var color: String {
        switch self {
        case .bakerloo: return "#B36305"
        case .central: return "#E32017"
        case .circle: return "#FFD300"
        case .district: return "#00782A"
        case .hammersmithCity: return "#F3A9BB"
        case .jubilee: return "#A0A5A9"
        case .metropolitan: return "#9B0056"
        case .northern: return "#000000"
        case .piccadilly: return "#003688"
        case .victoria: return "#0098D4"
        case .waterlooCity: return "#95CDBA"
        case .dlr: return "#00A4A7"
        case .elizabeth: return "#6950A1"
        case .overground: return "#EE7C0E"
        }
    }
}

/// Pre-defined London calm spots with real coordinates
extension CalmSpot {
    static let allSpots: [CalmSpot] = [
        CalmSpot(
            name: "Kyoto Garden",
            description: "A serene Japanese garden in Holland Park with koi ponds, waterfalls, and peacocks. Perfect for meditation.",
            coordinate: CLLocationCoordinate2D(latitude: 51.5022, longitude: -0.2034),
            nearestTube: TubeStation(
                name: "Holland Park",
                lines: [.central],
                coordinate: CLLocationCoordinate2D(latitude: 51.5075, longitude: -0.2060),
                walkingMinutes: 5
            ),
            imageURL: "https://images.unsplash.com/photo-1545569341-9eb8b30979d9?w=800",
            systemImage: "leaf.fill",
            tags: ["Japanese", "Garden", "Peaceful", "Waterfall"],
            openingHours: "7:30 AM - Dusk",
            crowdLevel: .quiet
        ),
        CalmSpot(
            name: "St Dunstan in the East",
            description: "A stunning ruined church garden with climbing vines and Gothic arches. A hidden urban oasis.",
            coordinate: CLLocationCoordinate2D(latitude: 51.5095, longitude: -0.0830),
            nearestTube: TubeStation(
                name: "Monument",
                lines: [.circle, .district],
                coordinate: CLLocationCoordinate2D(latitude: 51.5107, longitude: -0.0859),
                walkingMinutes: 4
            ),
            imageURL: "https://images.unsplash.com/photo-1587474260584-136574528ed5?w=800",
            systemImage: "building.columns.fill",
            tags: ["Historic", "Ruins", "Garden", "Photography"],
            openingHours: "8:00 AM - 7:00 PM",
            crowdLevel: .moderate
        ),
        CalmSpot(
            name: "Postman's Park",
            description: "A tranquil Victorian park featuring the Memorial to Heroic Self-Sacrifice with touching plaques.",
            coordinate: CLLocationCoordinate2D(latitude: 51.5170, longitude: -0.0976),
            nearestTube: TubeStation(
                name: "St Paul's",
                lines: [.central],
                coordinate: CLLocationCoordinate2D(latitude: 51.5152, longitude: -0.0976),
                walkingMinutes: 3
            ),
            imageURL: "https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800",
            systemImage: "envelope.fill",
            tags: ["Historic", "Memorial", "Quiet", "Benches"],
            openingHours: "8:00 AM - Dusk",
            crowdLevel: .quiet
        ),
        CalmSpot(
            name: "Camley Street Natural Park",
            description: "A wildlife reserve near King's Cross with ponds, meadows, and woodland. Urban nature at its best.",
            coordinate: CLLocationCoordinate2D(latitude: 51.5398, longitude: -0.1261),
            nearestTube: TubeStation(
                name: "King's Cross St Pancras",
                lines: [.northern, .piccadilly, .victoria, .hammersmithCity, .circle, .metropolitan],
                coordinate: CLLocationCoordinate2D(latitude: 51.5303, longitude: -0.1237),
                walkingMinutes: 10
            ),
            imageURL: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800",
            systemImage: "bird.fill",
            tags: ["Wildlife", "Nature", "Ponds", "Birdwatching"],
            openingHours: "10:00 AM - 5:00 PM",
            crowdLevel: .quiet
        ),
        CalmSpot(
            name: "Isabella Plantation",
            description: "An ornamental woodland garden in Richmond Park, famous for azaleas and rhododendrons.",
            coordinate: CLLocationCoordinate2D(latitude: 51.4380, longitude: -0.2720),
            nearestTube: TubeStation(
                name: "Richmond",
                lines: [.district, .overground],
                coordinate: CLLocationCoordinate2D(latitude: 51.4631, longitude: -0.3013),
                walkingMinutes: 25
            ),
            imageURL: "https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=800",
            systemImage: "camera.macro",
            tags: ["Flowers", "Woodland", "Photography", "Nature"],
            openingHours: "7:00 AM - Dusk",
            crowdLevel: .quiet
        ),
        CalmSpot(
            name: "Chelsea Physic Garden",
            description: "London's oldest botanic garden (1673) with medicinal plants and a peaceful atmosphere.",
            coordinate: CLLocationCoordinate2D(latitude: 51.4847, longitude: -0.1635),
            nearestTube: TubeStation(
                name: "Sloane Square",
                lines: [.circle, .district],
                coordinate: CLLocationCoordinate2D(latitude: 51.4924, longitude: -0.1565),
                walkingMinutes: 12
            ),
            imageURL: "https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800",
            systemImage: "cross.vial.fill",
            tags: ["Historic", "Botanic", "Medicinal", "Educational"],
            openingHours: "11:00 AM - 6:00 PM",
            crowdLevel: .moderate
        ),
        CalmSpot(
            name: "Horniman Gardens",
            description: "Beautiful Victorian gardens in Forest Hill with stunning views of London and a bandstand.",
            coordinate: CLLocationCoordinate2D(latitude: 51.4409, longitude: -0.0600),
            nearestTube: TubeStation(
                name: "Forest Hill",
                lines: [.overground],
                coordinate: CLLocationCoordinate2D(latitude: 51.4395, longitude: -0.0534),
                walkingMinutes: 8
            ),
            imageURL: "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800",
            systemImage: "music.note",
            tags: ["Views", "Victorian", "Museum", "Family"],
            openingHours: "7:15 AM - Sunset",
            crowdLevel: .moderate
        ),
        CalmSpot(
            name: "Phoenix Garden",
            description: "A hidden community garden in the heart of the West End, perfect for escaping the crowds.",
            coordinate: CLLocationCoordinate2D(latitude: 51.5140, longitude: -0.1285),
            nearestTube: TubeStation(
                name: "Tottenham Court Road",
                lines: [.central, .northern, .elizabeth],
                coordinate: CLLocationCoordinate2D(latitude: 51.5165, longitude: -0.1310),
                walkingMinutes: 3
            ),
            imageURL: "https://images.unsplash.com/photo-1416169607655-0c2b3ce2e1cc?w=800",
            systemImage: "flame.fill",
            tags: ["Community", "Hidden", "Central", "Wildlife"],
            openingHours: "8:30 AM - Dusk",
            crowdLevel: .quiet
        ),
        CalmSpot(
            name: "Barbican Conservatory",
            description: "London's second-largest conservatory with tropical plants and fish ponds inside the Barbican.",
            coordinate: CLLocationCoordinate2D(latitude: 51.5204, longitude: -0.0938),
            nearestTube: TubeStation(
                name: "Barbican",
                lines: [.circle, .hammersmithCity, .metropolitan],
                coordinate: CLLocationCoordinate2D(latitude: 51.5201, longitude: -0.0978),
                walkingMinutes: 2
            ),
            imageURL: "https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=800",
            systemImage: "leaf.arrow.triangle.circlepath",
            tags: ["Tropical", "Indoor", "Architecture", "Fish"],
            openingHours: "Sundays only, 12:00 PM - 5:00 PM",
            crowdLevel: .busy
        ),
        CalmSpot(
            name: "Mudchute Park & Farm",
            description: "The largest urban farm in Europe on the Isle of Dogs with animals and open meadows.",
            coordinate: CLLocationCoordinate2D(latitude: 51.4893, longitude: -0.0140),
            nearestTube: TubeStation(
                name: "Mudchute",
                lines: [.dlr],
                coordinate: CLLocationCoordinate2D(latitude: 51.4876, longitude: -0.0143),
                walkingMinutes: 2
            ),
            imageURL: "https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=800",
            systemImage: "hare.fill",
            tags: ["Farm", "Animals", "Family", "Free"],
            openingHours: "9:00 AM - 4:00 PM",
            crowdLevel: .moderate
        )
    ]
}
