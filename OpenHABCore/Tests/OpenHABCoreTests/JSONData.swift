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

// swiftlint:disable line_length
let jsonSitemap3 = """
[{"name":"myHome","label":"myHome","link":"https://192.168.2.63:8444/rest/sitemaps/myHome","homepage":{"link":"https://192.168.2.63:8444/rest/sitemaps/myHome/myHome","leaf":false,"timeout":false,"widgets":[]}},{"name":"grafana","label":"grafana","link":"https://192.168.2.63:8444/rest/sitemaps/grafana","homepage":{"link":"https://192.168.2.63:8444/rest/sitemaps/grafana/grafana","leaf":false,"timeout":false,"widgets":[]}},{"name":"_default","label":"Home","link":"https://192.168.2.63:8444/rest/sitemaps/_default","homepage":{"link":"https://192.168.2.63:8444/rest/sitemaps/_default/_default","leaf":false,"timeout":false,"widgets":[]}}]
"""
// swiftlint:enable line_length

/// Anonymised myopenHAB cloud notification list response (real JSON shape as of 2026).
/// Actions and on-click are nested inside `payload`; the top-level fields carry only
/// the plain message text and metadata. Covers both a rich notification (with actions)
/// and a hide-notification control message (payload.type == "hideNotification").
let jsonCloudNotifications = """
[
  {
    "_id": "aabbccdd112233440000aaaa",
    "user": "aabbccdd112233440000bbbb",
    "message": "Window open, turning off heating.",
    "severity": "window_open",
    "acknowledged": false,
    "payload": {
      "on-click": "ui:/basicui/app?w=0_01&sitemap=page_00000000",
      "reference-id": "00000000-0000-0000-0000-000000000001",
      "tag": "window_open",
      "type": "notification",
      "message": "Window open, turning off heating.",
      "title": "Window open detected",
      "actions": [
        { "action": "rule:restore_heating:-", "title": "Turn heating back on" }
      ]
    },
    "created": "2026-01-01T12:00:00.000Z",
    "__v": 0
  },
  {
    "_id": "aabbccdd112233440000cccc",
    "user": "aabbccdd112233440000bbbb",
    "message": "",
    "severity": "window_open",
    "acknowledged": false,
    "payload": {
      "tag": "window_open",
      "type": "hideNotification"
    },
    "created": "2026-01-01T11:59:00.000Z",
    "__v": 0
  }
]
"""

let jsonGroup = """
{
  "version": "8",
  "locale": "en_DE",
  "measurementSystem": "SI",
  "runtimeInfo": {
    "version": "4.3.2",
    "buildString": "Release Build"
  },
  "links": [
    {
      "type": "config-descriptions",
      "url": "http://192.168.2.10:8080/rest/config-descriptions"
    },
    {
      "type": "auth",
      "url": "http://192.168.2.10:8080/rest/auth"
    },
    {
      "type": "habpanel",
      "url": "http://192.168.2.10:8080/rest/habpanel"
    },
    {
      "type": "sitemaps",
      "url": "http://192.168.2.10:8080/rest/sitemaps"
    },
    {
      "type": "persistence",
      "url": "http://192.168.2.10:8080/rest/persistence"
    },
    {
      "type": "addons",
      "url": "http://192.168.2.10:8080/rest/addons"
    },
    {
      "type": "things",
      "url": "http://192.168.2.10:8080/rest/things"
    },
    {
      "type": "channel-types",
      "url": "http://192.168.2.10:8080/rest/channel-types"
    },
    {
      "type": "profile-types",
      "url": "http://192.168.2.10:8080/rest/profile-types"
    },
    {
      "type": "module-types",
      "url": "http://192.168.2.10:8080/rest/module-types"
    },
    {
      "type": "links",
      "url": "http://192.168.2.10:8080/rest/links"
    },
    {
      "type": "thing-types",
      "url": "http://192.168.2.10:8080/rest/thing-types"
    },
    {
      "type": "tags",
      "url": "http://192.168.2.10:8080/rest/tags"
    },
    {
      "type": "discovery",
      "url": "http://192.168.2.10:8080/rest/discovery"
    },
    {
      "type": "events",
      "url": "http://192.168.2.10:8080/rest/events"
    },
    {
      "type": "rules",
      "url": "http://192.168.2.10:8080/rest/rules"
    },
    {
      "type": "services",
      "url": "http://192.168.2.10:8080/rest/services"
    },
    {
      "type": "items",
      "url": "http://192.168.2.10:8080/rest/items"
    },
    {
      "type": "actions",
      "url": "http://192.168.2.10:8080/rest/actions"
    },
    {
      "type": "logging",
      "url": "http://192.168.2.10:8080/rest/logging"
    },
    {
      "type": "audio",
      "url": "http://192.168.2.10:8080/rest/audio"
    },
    {
      "type": "voice",
      "url": "http://192.168.2.10:8080/rest/voice"
    },
    {
      "type": "templates",
      "url": "http://192.168.2.10:8080/rest/templates"
    },
    {
      "type": "inbox",
      "url": "http://192.168.2.10:8080/rest/inbox"
    },
    {
      "type": "systeminfo",
      "url": "http://192.168.2.10:8080/rest/systeminfo"
    },
    {
      "type": "ui",
      "url": "http://192.168.2.10:8080/rest/ui"
    },
    {
      "type": "transformations",
      "url": "http://192.168.2.10:8080/rest/transformations"
    },
    {
      "type": "uuid",
      "url": "http://192.168.2.10:8080/rest/uuid"
    },
    {
      "type": "spec",
      "url": "http://192.168.2.10:8080/rest/spec"
    },
    {
      "type": "iconsets",
      "url": "http://192.168.2.10:8080/rest/iconsets"
    }
  ]
}
"""
