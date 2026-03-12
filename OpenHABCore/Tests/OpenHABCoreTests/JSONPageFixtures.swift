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

let jsonSitemap = Data(
    """
    {
      "id": "myHome",
      "title": "myHome",
      "link": "https://myopenhab.org/rest/sitemaps/myHome/myHome",
      "leaf": false,
      "timeout": false,
      "widgets": [
        {
          "widgetId": "00",
          "type": "Frame",
          "label": "Treppe",
          "icon": "frame",
          "mappings": [],
          "widgets": []
        }
      ]
    }
    """.utf8
)

let jsonSitemap2 = Data(
    """
    {
      "id": "grafana",
      "title": "grafana",
      "link": "https://myopenhab.org/rest/sitemaps/grafana/grafana",
      "leaf": false,
      "timeout": false,
      "widgets": [
        { "widgetId": "00", "type": "Frame", "label": "A", "icon": "frame", "mappings": [], "widgets": [] },
        { "widgetId": "01", "type": "Frame", "label": "B", "icon": "frame", "mappings": [], "widgets": [] },
        { "widgetId": "02", "type": "Frame", "label": "C", "icon": "frame", "mappings": [], "widgets": [] },
        { "widgetId": "03", "type": "Frame", "label": "D", "icon": "frame", "mappings": [], "widgets": [] },
        {
          "widgetId": "04",
          "type": "Frame",
          "label": "E",
          "icon": "frame",
          "mappings": [],
          "widgets": [
            { "widgetId": "0400", "type": "Text", "label": "one", "icon": "text", "mappings": [], "widgets": [] },
            { "widgetId": "0401", "type": "Text", "label": "two", "icon": "text", "mappings": [], "widgets": [] },
            { "widgetId": "0402", "type": "Text", "label": "three", "icon": "text", "mappings": [], "widgets": [] },
            {
              "widgetId": "0403",
              "type": "Text",
              "label": "moon",
              "icon": "text",
              "mappings": [],
              "item": {
                "link": "https://myopenhab.org/rest/items/moon",
                "state": "NEW",
                "stateDescription": {
                  "readOnly": true,
                  "options": [
                    { "value": "NEW", "label": "New moon" }
                  ]
                },
                "editable": false,
                "type": "String",
                "name": "moon",
                "label": "Moon",
                "tags": [],
                "groupNames": []
              },
              "widgets": []
            }
          ]
        }
      ]
    }
    """.utf8
)
