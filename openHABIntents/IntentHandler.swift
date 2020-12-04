// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Intents
import OpenHABCore

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is OpenHABGetItemStateIntent: return GetItemStateIntentHandler()
        case is OpenHABSetSwitchStateIntent: return SetSwitchStateIntentHandler()
        case is OpenHABSetNumberValueIntent: return SetNumberValueIntentHandler()
        case is OpenHABSetStringValueIntent: return SetStringValueIntentHandler()
        case is OpenHABSetColorValueIntent: return SetColorValueIntentHandler()
        case is OpenHABSetContactStateValueIntent: return SetContactStateValueIntentHandler()
        default: return SetDimmerRollerValueIntentHandler()
        }
    }
}
