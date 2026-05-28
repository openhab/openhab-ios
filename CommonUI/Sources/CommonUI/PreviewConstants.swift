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

import Foundation
import OpenHABCore
import os.log

#if DEBUG
// swiftlint:disable type_body_length
public enum PreviewConstants {
    public static let logger = Logger(subsystem: "org.openhab", category: "PreviewConstants")

    public static let remoteURLString = "http://192.168.2.10:8080"

    public static var openHABSitemapPage: OpenHABPage? {
        let data = sitemapJson
        do {
            let sitemapPage = try data.decoded(as: Components.Schemas.PageDTO.self)
            return OpenHABPage(sitemapPage)
        } catch {
            logger.error("Should not throw \(error.localizedDescription)")
            return nil
        }
    }

    public static let sitemapJson = Data("""
    {
        "id": "watch",
        "title": "watch",
        "link": "http://192.168.2.10:8080/rest/sitemaps/watch/watch",
        "leaf": true,
        "timeout": false,
        "widgets": [
            {
                "widgetId": "00",
                "type": "Switch",
                "visibility": true,
                "label": "Licht Keller WC Decke",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightSwitch6_1",
                    "state": "OFF",
                    "type": "Switch",
                    "name": "lcnLightSwitch6_1",
                    "label": "Licht Keller WC Decke",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "gKellerLicht",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "01",
                "type": "Switch",
                "visibility": true,
                "label": "Licht Oberlicht",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightSwitch14_1",
                    "state": "OFF",
                    "type": "Switch",
                    "name": "lcnLightSwitch14_1",
                    "label": "Licht Oberlicht",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "gEGLicht",
                        "G_PresenceSimulation",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "02",
                "type": "Switch",
                "visibility": true,
                "label": "Licht Esstisch [Test]",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightSwitch20_1",
                    "state": "ON",
                    "type": "Switch",
                    "name": "lcnLightSwitch20_1",
                    "label": "Licht Esstisch",
                    "tags": [],
                    "groupNames": [
                        "gEGLicht",
                        "G_PresenceSimulation",
                        "gLcn",
                        "gStateON"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "03",
                "type": "Slider",
                "visibility": true,
                "label": "Esstisch [100]",
                "icon": "slider",
                "mappings": [],
                "switchSupport": false,
                "sendFrequency": 0,
                "item": {
                    "link": "http://192.168.2.10:8080/rest/items/lcnLightDimmer",
                    "state": "95",
                    "stateDescription": {
                        "pattern": "%s",
                        "readOnly": false,
                        "options": []
                    },
                    "type": "Dimmer",
                    "name": "lcnLightDimmer",
                    "label": "Esstisch",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "gEGLicht",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "04",
                "type": "Switch",
                "visibility": true,
                "label": "Fernsteuerung",
                "icon": "switch",
                "mappings": [
                    {
                        "command": "0",
                        "label": "Overwrite"
                    },
                    {
                        "command": "1",
                        "label": "Kalender"
                    },
                    {
                        "command": "2",
                        "label": "Automatik"
                    }
                ],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/Automatik",
                    "state": "2",
                    "type": "String",
                    "name": "Automatik",
                    "tags": [],
                    "groupNames": []
                },
                "widgets": []
            },
            {
                "widgetId": "05",
                "type": "Switch",
                "visibility": true,
                "label": "Jalousie WZ Süd links",
                "icon": "rollershutter",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnJalousieWZSuedLinks",
                    "state": "0",
                    "type": "Rollershutter",
                    "name": "lcnJalousieWZSuedLinks",
                    "label": "Jalousie WZ Süd links",
                    "tags": [],
                    "groupNames": [
                        "gWZ",
                        "gEGJalousien",
                        "gHausJalousie",
                        "gJalousienSued",
                        "gEGJalousienSued",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "06",
                "type": "Setpoint",
                "visibility": true,
                "label": "Setpoint Temperature [21.0 °C]",
                "icon": "temperature",
                "mappings": [],
                "minValue": 8,
                "maxValue": 25,
                "step": 0.5,
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/ZimmerPaul_SetpointTemperature",
                    "state": "21.0 °C",
                    "stateDescription": {
                        "pattern": "%.1f %unit%",
                        "readOnly": false,
                        "options": []
                    },
                    "type": "Number:Temperature",
                    "name": "ZimmerPaul_SetpointTemperature",
                    "label": "Setpoint Temperature [%.1f °C]",
                    "category": "Temperature",
                    "tags": [],
                    "groupNames": []
                },
                "widgets": []
            },
            {
                "widgetId": "07",
                "type": "Text",
                "visibility": true,
                "label": "Aussentemperatur [11.5 °C]",
                "icon": "temperature",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/TempAussen",
                    "state": "11.5",
                    "stateDescription": {
                        "pattern": "%.1f °C",
                        "readOnly": false,
                        "options": []
                    },
                    "type": "Number",
                    "name": "TempAussen",
                    "label": "Aussentemperatur",
                    "category": "temperature",
                    "tags": [],
                    "groupNames": [
                        "gOnewire"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "08",
                "type": "Image",
                "visibility": true,
                "label": "",
                "icon": "image",
                "mappings": [],
                "url": "http://192.168.2.15:8081/proxy?sitemap=watch.sitemap&widgetId=08",
                "widgets": []
            },
            {
                "widgetId": "09",
                "type": "Mapview",
                "visibility": true,
                "label": "Location [-°N -°E -m]",
                "icon": "mapview",
                "mappings": [],
                "height": 5,
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/GPSTrackerTi_Location",
                    "state":"52.5200066,13.4049540",
                    "stateDescription": {
                        "pattern": "%2$s°N %3$s°E %1$sm",
                        "readOnly": true,
                        "options": []
                    },
                    "type": "Location",
                    "name": "GPSTrackerTi_Location",
                    "label": "Location",
                    "tags": [],
                    "groupNames": []
                },
                "widgets": []
            },
            {
                       "widgetId": "10",
                       "type": "Colorpicker",
                       "visibility": true,
                       "label": "Color",
                       "icon": "colorlight",
                       "mappings": [],
                       "item": {
                           "link": "http://192.168.2.160:8080/rest/items/LEDVANCECLA60RGBWZ3_Color",
                           "state": "UNDEF",
                           "type": "Color",
                           "name": "LEDVANCECLA60RGBWZ3_Color",
                           "label": "Color",
                           "category": "ColorLight",
                           "tags": [],
                           "groupNames": [
                               "dg_AllItems"
                           ]
                       },
                       "widgets": []
            },
               {
                    "widgetId": "11",
                    "type": "Setpoint",
                    "visibility": true,
                    "label": "item in seconds [2400.0 s]",
                    "labelSource": "SITEMAP_WIDGET",
                    "icon": "",
                    "staticIcon": false,
                    "pattern": "%.1f s",
                    "unit": "s",
                    "mappings": [],
                    "minValue": 300,
                    "maxValue": 3600,
                    "step": 60,
                    "item": {
                      "link": "http://192.168.2.10:8080/rest/items/testTime",
                      "state": "2400 s",
                      "stateDescription": {
                        "pattern": "%.0f %unit%",
                        "readOnly": false,
                        "options": []
                      },
                      "unitSymbol": "s",
                      "type": "Number:Time",
                      "name": "testTime",
                      "label": "",
                      "category": "",
                      "tags": [],
                      "groupNames": []
                    },
                    "widgets": []
                  },
                  {
                    "widgetId": "12",
                    "type": "Setpoint",
                    "visibility": true,
                    "label": "item in minutes [40.0 min]",
                    "labelSource": "SITEMAP_WIDGET",
                    "icon": "",
                    "staticIcon": false,
                    "pattern": "%.1f min",
                    "unit": "min",
                    "mappings": [],
                    "minValue": 5,
                    "maxValue": 60,
                    "step": 5,
                    "state": "40 min",
                    "item": {
                      "link": "http://192.168.2.10:8080/rest/items/testTime",
                      "state": "2400 s",
                      "stateDescription": {
                        "pattern": "%.0f %unit%",
                        "readOnly": false,
                        "options": []
                      },
                      "unitSymbol": "s",
                      "type": "Number:Time",
                      "name": "testTime",
                      "label": "",
                      "category": "",
                      "tags": [],
                      "groupNames": []
                    },
                    "widgets": []
                  },
              {
                "widgetId": "13",
                "type": "Colortemperaturepicker",
                "visibility": true,
                "label": "Color Temperature [2700 K]",
                "labelSource": "SITEMAP_WIDGET",
                "icon": "colorwheel",
                "staticIcon": true,
                "pattern": "%.0f %unit%",
                "unit": "K",
                "mappings": [],
                "item": {
                  "link": "http://192.168.2.10:8080/rest/items/test_LEDLight_ColorTemp",
                  "state": "2700.0 K",
                  "stateDescription": {
                    "pattern": "%.0f %unit%",
                    "readOnly": false,
                    "options": []
                  },
                  "unitSymbol": "K",
                  "type": "Number:Temperature",
                  "name": "test_LEDLight_ColorTemp",
                  "label": "",
                  "category": "",
                  "tags": [],
                  "groupNames": []
                },
                "widgets": []
              },
              {
                "widgetId": "14",
                "type": "Slider",
                "visibility": true,
                "label": "Brightness",
                "labelSource": "SITEMAP_WIDGET",
                "icon": "",
                "staticIcon": false,
                "unit": "",
                "mappings": [],
                "switchSupport": false,
                "releaseOnly": false,
                "item": {
                  "link": "http://192.168.2.10:8080/rest/items/test_LEDLight_Brightness",
                  "state": "NULL",
                  "type": "Dimmer",
                  "name": "test_LEDLight_Brightness",
                  "label": "",
                  "category": "",
                  "tags": [],
                  "groupNames": []
                },
                "widgets": []
              },
                  {
                    "widgetId": "15",
                    "type": "Colorpicker",
                    "visibility": true,
                    "label": "Color",
                    "labelSource": "SITEMAP_WIDGET",
                    "icon": "colorwheel",
                    "staticIcon": false,
                    "unit": "",
                    "mappings": [],
                    "item": {
                      "link": "http://192.168.2.10:8080/rest/items/test_LEDLight_color",
                      "state": "0,0,73",
                      "type": "Color",
                      "name": "test_LEDLight_color",
                      "label": "test_LEDLight_color",
                      "category": "",
                      "tags": [],
                      "groupNames": []
                    },
                    "widgets": []
                  },
                  {
                    "widgetId": "16",
                    "type": "Buttongrid",
                    "visibility": true,
                    "label": "Remote Control [-]",
                    "labelSource": "SITEMAP_WIDGET",
                    "icon": "screen",
                    "staticIcon": true,
                    "pattern": "%s",
                    "unit": "",
                    "mappings": [
                      {
                        "row": 1,
                        "column": 1,
                        "command": "POWER",
                        "label": "Power",
                        "icon": "switch-off"
                      },
                      {
                        "row": 1,
                        "column": 2,
                        "command": "MENU",
                        "label": "Menu"
                      },
                      {
                        "row": 1,
                        "column": 3,
                        "command": "EXIT",
                        "label": "Exit"
                      },
                      {
                        "row": 2,
                        "column": 2,
                        "command": "UP",
                        "label": "Up",
                        "icon": "f7:arrowtriangle_up"
                      },
                      {
                        "row": 2,
                        "column": 4,
                        "command": "VOL_PLUS",
                        "label": "Volume +"
                      },
                      {
                        "row": 3,
                        "column": 1,
                        "command": "LEFT",
                        "label": "Left",
                        "icon": "f7:arrowtriangle_left"
                      },
                      {
                        "row": 3,
                        "column": 2,
                        "command": "OK",
                        "label": "Ok"
                      },
                      {
                        "row": 3,
                        "column": 3,
                        "command": "RIGHT",
                        "label": "Right",
                        "icon": "f7:arrowtriangle_right"
                      },
                      {
                        "row": 3,
                        "column": 4,
                        "command": "MUTE",
                        "label": "Mute",
                        "icon": "soundvolume_mute"
                      },
                      {
                        "row": 4,
                        "column": 2,
                        "command": "DOWN",
                        "label": "Down",
                        "icon": "f7:arrowtriangle_down"
                      },
                      {
                        "row": 4,
                        "column": 4,
                        "command": "VOL_MINUS",
                        "label": "Volume -"
                      }
                    ],
                    "item": {
                      "link": "http://192.168.2.10:8080/rest/items/test_RemoteControl",
                      "state": "NULL",
                      "stateDescription": {
                        "pattern": "%s",
                        "readOnly": false,
                        "options": []
                      },
                      "type": "String",
                      "name": "test_RemoteControl",
                      "label": "test_RemoteControl",
                      "category": "",
                      "tags": [],
                      "groupNames": []
                    },
                    "widgets": []
                  },
     {
            "widgetId": "17",
            "type": "Input",
            "visibility": true,
            "label": "Meter [166000]",
            "labelSource": "SITEMAP_WIDGET",
            "icon": "energy",
            "staticIcon": true,
            "pattern": "%.0f %unit%",
            "unit": "",
            "mappings": [],
            "inputHint": "number",
            "item": {
              "link": "http://192.168.2.10:8080/rest/items/Test_Meter_Reading",
              "state": "166000.0",
              "stateDescription": {
                "pattern": "%.0f",
                "readOnly": false,
                "options": []
              },
              "type": "Number",
              "name": "Test_Meter_Reading",
              "label": "Test_Meter_Reading",
              "category": "",
              "tags": [],
              "groupNames": []
            },
            "widgets": []
          },

        ]
    }
    """.utf8)
}

// swiftlint:enable type_body_length
#endif
