// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SFSafeSymbols

/// Maps openHAB classic icon names to SF Symbols.
/// - Parameters:
///   - iconName: The raw `widget.icon` string (case-insensitive, numeric suffixes stripped automatically).
///   - isOn: Whether the item is in an active/on state, used to choose fill vs. outline variants.
public func openHABSFSymbol(for iconName: String, isOn: Bool) -> SFSymbol {
    // Strip trailing numeric variant suffixes: "baby_1" → "baby", "washingmachine_2" → "washingmachine"
    let icon = iconName.lowercased()
        .replacingOccurrences(of: #"_?\d+$"#, with: "", options: .regularExpression)

    // swiftlint:disable:next cyclomatic_complexity
    return switch icon {

    // ── Places ────────────────────────────────────────────────────────────────
    case "attic":
        isOn ? .houseFill : .house
    case "bath":
        isOn ? .bathtubFill : .bathtub
    case "bedroom", "bedroom_blue", "bedroom_orange", "bedroom_red":
        isOn ? .bedDoubleFill : .bedDouble
    case "cellar", "pantry":
        isOn ? .archiveboxFill : .archivebox
    case "corridor":
        isOn ? .doorLeftHandOpen : .doorLeftHandClosed           // no fill
    case "firstfloor":
        isOn ? ._1CircleFill : ._1Circle
    case "garage", "garage_detached", "garage_detached_selected":
        isOn ? .doorGarageDoubleBayOpen : .doorGarageDoubleBayClosed // no fill
    case "garden", "greenhouse":
        isOn ? .leafFill : .leaf
    case "groundfloor":
        isOn ? ._0CircleFill : ._0Circle
    case "kitchen":
        isOn ? .fryingPanFill : .fryingPan
    case "office":
        isOn ? .briefcaseFill : .briefcase
    case "terrace":
        isOn ? .sunMaxFill : .sunMax

    // ── Things ────────────────────────────────────────────────────────────────
    case "battery", "batterylevel":
        isOn ? .battery100percent : .battery0percent             // no fill
    case "blinds", "rollershutter":
        isOn ? .blindsVerticalOpen : .blindsVerticalClosed       // no fill
    case "camera":
        isOn ? .cameraFill : .camera
    case "door":
        isOn ? .doorLeftHandOpen : .doorLeftHandClosed           // no fill
    case "frontdoor":
        isOn ? .doorFrenchOpen : .doorFrenchClosed               // no fill
    case "garagedoor":
        isOn ? .doorGarageDoubleBayOpen : .doorGarageDoubleBayClosed // no fill
    case "lawnmower":
        isOn ? .leafFill : .leaf                                 // no lawnmower SF symbol
    case "lock", "security":
        isOn ? .lockFill : .lockOpen
    case "poweroutlet", "poweroutlet_au", "poweroutlet_eu", "poweroutlet_uk", "poweroutlet_us":
        isOn ? .powerplugFill : .powerplug
    case "projector", "screen", "cinemascreen":
        isOn ? .tvFill : .tv
    case "receiver":
        isOn ? .hifireceiverFill : .hifireceiver
    case "siren":
        isOn ? .lightBeaconMaxFill : .lightBeaconMax
    case "wallswitch":
        isOn ? .lightswitchOnFill : .lightswitchOffFill
    case "whitegood", "washingmachine":
        isOn ? .washerFill : .washer
    case "window":
        isOn ? .windowVerticalOpen : .windowVerticalClosed       // no fill

    // ── Weather ───────────────────────────────────────────────────────────────
    case "humidity":
        isOn ? .humidityFill : .humidity
    case "moon":
        isOn ? .moonFill : .moon
    case "rain":
        isOn ? .cloudRainFill : .cloudRain
    case "snow":
        isOn ? .cloudSnowFill : .cloudSnow                       // snowflake has no fill
    case "sun":
        isOn ? .sunMaxFill : .sunMax
    case "sun_clouds":
        isOn ? .cloudSunFill : .cloudSun
    case "temperature":
        .thermometerMedium                                       // no fill
    case "wind":
        .wind                                                    // no fill

    // ── Properties ───────────────────────────────────────────────────────────
    case "carbondioxide":
        isOn ? .smokeFill : .smoke
    case "colorlight", "rgb":
        isOn ? .lightbulbFill : .lightbulb
    case "energy":
        isOn ? .boltFill : .bolt
    case "fire", "gas":
        isOn ? .flameFill : .flame
    case "flow", "flowpipe", "pump":
        isOn ? .arrowUpCircleFill : .arrowUpCircle
    case "lowbattery":
        .battery0percent                                         // no fill
    case "motion":
        isOn ? .sensorTagRadiowavesForwardFill : .sensorTagRadiowavesForward
    case "oil":
        isOn ? .oilcanFill : .oilcan
    case "pressure":
        .barometer                                               // no fill
    case "price":
        isOn ? .dollarsignCircleFill : .dollarsignCircle
    case "qualityofservice", "network":
        isOn ? .wifiCircleFill : .wifiCircle                    // wifi has no fill
    case "smoke":
        isOn ? .smokeFill : .smoke
    case "soundvolume":
        isOn ? .speakerWave3Fill : .speakerWave3
    case "time":
        isOn ? .clockFill : .clock
    case "water", "cistern", "faucet", "niveau", "sewerage", "softener":
        isOn ? .dropFill : .drop

    // ── Channels / Widgets ───────────────────────────────────────────────────
    case "colorpicker", "colorwheel":
        isOn ? .paintpaletteFill : .paintpalette
    case "group":
        isOn ? .rectangle3GroupFill : .rectangle3Group
    case "slider":
        .sliderHorizontal3                                       // no fill
    case "switch":
        isOn ? .lightswitchOnFill : .lightswitchOffFill
    case "text":
        isOn ? .docTextFill : .docText

    // ── Control ───────────────────────────────────────────────────────────────
    case "heating":
        if #available(iOS 26.0, *) {
            isOn ? .heatWavesCircleFill : .heatWavesCircle
        } else {
            isOn ? .flameFill : .flame
        }
    case "mediacontrol":
        isOn ? .playCircleFill : .playCircle
    case "movecontrol":
        isOn ? .gamecontrollerFill : .gamecontroller
    case "zoom":
        isOn ? .magnifyingglassCircleFill : .magnifyingglassCircle

    // ── Purpose ───────────────────────────────────────────────────────────────
    case "alarm":
        isOn ? .alarmFill : .alarm
    case "party":
        isOn ? .partyPopperFill : .partyPopper
    case "presence":
        isOn ? .sensorTagRadiowavesForwardFill : .sensorTagRadiowavesForward
    case "vacation":
        isOn ? .suitcaseFill : .suitcase

    // ── Other ─────────────────────────────────────────────────────────────────
    case "baby", "boy", "girl", "man", "woman", "contact":
        isOn ? .personFill : .person
    case "bluetooth":
        isOn ? .waveformCircleFill : .waveformCircle            // no bluetooth SF symbol
    case "calendar":
        isOn ? .calendarCircleFill : .calendarCircle            // calendar has no fill
    case "chart", "pie":
        isOn ? .chartBarFill : .chartBar
    case "cinema", "video":
        isOn ? .movieclapperFill : .movieclapper
    case "climate":
        isOn ? .thermometerSunFill : .thermometerSun
    case "dryer":
        isOn ? .dryerFill : .dryer
    case "error":
        isOn ? .exclamationmarkCircleFill : .exclamationmarkCircle
    case "fan", "fan_box":
        isOn ? .fanFill : .fan
    case "fan_ceiling":
        isOn ? .fanCeilingFill : .fanCeiling
    case "house":
        isOn ? .houseFill : .house
    case "incline":
        .chartLineUptrendXyaxis                                  // no fill
    case "input":
        isOn ? .trayAndArrowDownFill : .trayAndArrowDown
    case "keyring":
        isOn ? .keyHorizontalFill : .keyHorizontal
    case "lightbulb":
        isOn ? .lightbulbFill : .lightbulb
    case "line":
        .minus                                                   // no fill
    case "microphone":
        isOn ? .microphoneFill : .microphone
    case "none":
        isOn ? .circleFill : .circle
    case "outdoorlight", "lamp":
        isOn ? .lampFloorFill : .lampFloor
    case "parents":
        isOn ? .person2Fill : .person2
    case "piggybank":
        isOn ? .banknoteFill : .banknote
    case "player", "recorder":
        isOn ? .playCircleFill : .playCircle
    case "power":
        isOn ? .powerCircleFill : .powerCircle
    case "radiator":
        isOn ? .heaterVerticalFill : .heaterVertical
    case "returnpipe":
        .arrowUturnBackward                                      // no fill
    case "settings":
        isOn ? .gearshapeFill : .gearshape
    case "shield":
        isOn ? .shieldFill : .shield
    case "smiley":
        isOn ? .faceSmilingInverse : .faceSmiling
    case "sofa":
        isOn ? .sofaFill : .sofa
    case "solarplant":
        isOn ? .sunMaxCircleFill : .sunMaxCircle
    case "soundvolume_mute":
        isOn ? .speakerSlashFill : .speakerSlash
    case "status":
        isOn ? .infoCircleFill : .infoCircle
    case "suitcase":
        isOn ? .suitcaseFill : .suitcase
    case "sunrise":
        isOn ? .sunriseFill : .sunrise
    case "sunset":
        isOn ? .sunsetFill : .sunset
    case "temperature_cold":
        isOn ? .thermometerSnowflakeCircleFill : .thermometerSnowflakeCircle
    case "temperature_hot":
        isOn ? .thermometerSunFill : .thermometerSun
    case "toilet":
        isOn ? .toiletFill : .toilet
    case "wardrobe":
        isOn ? .tshirtFill : .tshirt

    // ── Keyword fallback for user-defined icon names ──────────────────────────
    default:
        if icon.contains("power") || icon.contains("switch") {
            isOn ? .powerCircleFill : .powerCircle
        } else if icon.contains("garage") {
            isOn ? .doorGarageDoubleBayOpen : .doorGarageDoubleBayClosed
        } else if icon.contains("lamp") || icon.contains("light") || icon.contains("bulb") {
            isOn ? .lightbulbFill : .lightbulb
        } else if icon.contains("lock") || icon.contains("alarm") || icon.contains("security") {
            isOn ? .lockFill : .lockOpen
        } else if icon.contains("house") || icon.contains("home") {
            isOn ? .houseFill : .house
        } else if icon.contains("heat") || icon.contains("fire") {
            isOn ? .flameFill : .flame
        } else if icon.contains("fan") {
            isOn ? .fanFill : .fan
        } else if icon.contains("water") || icon.contains("rain") {
            isOn ? .dropFill : .drop
        } else if icon.contains("person") || icon.contains("human") {
            isOn ? .personFill : .person
        } else {
            isOn ? .circleFill : .circle
        }
    }
}
