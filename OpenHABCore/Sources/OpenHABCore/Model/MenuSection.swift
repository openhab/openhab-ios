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

/// The four collapsible sections in the toolbar dropdown menu.
/// `allCases` defines the canonical default display order.
public enum MenuSection: String, Codable, CaseIterable, Hashable, Sendable {
    case mainUI
    case sitemaps
    case tiles
    case system
}
