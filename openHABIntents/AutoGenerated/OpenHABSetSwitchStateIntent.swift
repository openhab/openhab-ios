// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(OpenHABSetSwitchStateIntent)
public class OpenHABSetSwitchStateIntent: INIntent {
    @NSManaged public var item: String?
    @NSManaged public var action: String?
}

/*!
 @abstract Protocol to declare support for handling a OpenHABSetSwitchStateIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(OpenHABSetSwitchStateIntentHandling)
public protocol OpenHABSetSwitchStateIntentHandling: NSObjectProtocol {
    /*!
     @abstract Handling method - Execute the task represented by the OpenHABSetSwitchStateIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a OpenHABSetSwitchStateIntentResponse containing the details of the result of having executed the intent

     @see  OpenHABSetSwitchStateIntentResponse
     */
    @objc(handleSetSwitchState:completion:)
    func handle(intent: OpenHABSetSwitchStateIntent, completion: @escaping (OpenHABSetSwitchStateIntentResponse) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(handleSetSwitchState:completion:)
    func handle(intent: OpenHABSetSwitchStateIntent) async -> OpenHABSetSwitchStateIntentResponse

    /*!
     @abstract Dynamic options methods - provide options for the parameter at runtime
     @discussion Called to query dynamic options for the parameter and this intent in its current form.

     @param  intent The input intent
     @param  completion The response block contains options for the parameter
     */
    @available(iOS 14.0, macOS 10.16, watchOS 7.0, *)
    @objc(provideItemOptionsCollectionForSetSwitchState:withCompletion:)
    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(provideItemOptionsCollectionForSetSwitchState:withCompletion:)
    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<NSString>

    @available(iOS 14.0, macOS 10.16, watchOS 7.0, *)
    @objc(provideActionOptionsCollectionForSetSwitchState:withCompletion:)
    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(provideActionOptionsCollectionForSetSwitchState:withCompletion:)
    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<NSString>

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a OpenHABSetSwitchStateIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see OpenHABSetSwitchStateIntentResponse
     */
    @objc(confirmSetSwitchState:completion:)
    optional func confirm(intent: OpenHABSetSwitchStateIntent, completion: @escaping (OpenHABSetSwitchStateIntentResponse) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(confirmSetSwitchState:completion:)
    optional func confirm(intent: OpenHABSetSwitchStateIntent) async -> OpenHABSetSwitchStateIntentResponse

    /*!
     @abstract Default values for parameters with dynamic options
     @discussion Called to query the parameter default value.
     */
    @available(iOS 14.0, macOS 10.16, watchOS 7.0, *)
    @objc(defaultItemForSetSwitchState:)
    optional func defaultItem(for intent: OpenHABSetSwitchStateIntent) -> String?

    @available(iOS 14.0, macOS 10.16, watchOS 7.0, *)
    @objc(defaultActionForSetSwitchState:)
    optional func defaultAction(for intent: OpenHABSetSwitchStateIntent) -> String?

    /*!
     @abstract Deprecated dynamic options methods.
     */
    @available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
    @available(watchOS, introduced: 6.0, deprecated: 7.0, message: "")
    @objc(provideItemOptionsForSetSwitchState:withCompletion:)
    optional func provideItemOptions(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping ([String]?, Error?) -> Swift.Void)

    @available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
    @available(watchOS, introduced: 6.0, deprecated: 7.0, message: "")
    @objc(provideActionOptionsForSetSwitchState:withCompletion:)
    optional func provideActionOptions(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping ([String]?, Error?) -> Swift.Void)
}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum OpenHABSetSwitchStateIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
    case failureInvalidItem = 100
    case failureInvalidAction
}

@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(OpenHABSetSwitchStateIntentResponse)
public class OpenHABSetSwitchStateIntentResponse: INIntentResponse {
    @NSManaged public var item: String?
    @NSManaged public var action: String?

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc public fileprivate(set) var code: OpenHABSetSwitchStateIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    public convenience init(code: OpenHABSetSwitchStateIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

    /*!
     @abstract Initializes and returns the response object with the success code.
     */
    @objc(successIntentResponseWithAction:item:)
    public static func success(action: String, item: String) -> OpenHABSetSwitchStateIntentResponse {
        let intentResponse = OpenHABSetSwitchStateIntentResponse(code: .success, userActivity: nil)
        intentResponse.action = action
        intentResponse.item = item
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failureInvalidItem code.
     */
    @objc(failureInvalidItemIntentResponseWithItem:)
    public static func failureInvalidItem(_ item: String) -> OpenHABSetSwitchStateIntentResponse {
        let intentResponse = OpenHABSetSwitchStateIntentResponse(code: .failureInvalidItem, userActivity: nil)
        intentResponse.item = item
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failureInvalidAction code.
     */
    @objc(failureInvalidActionIntentResponseWithAction:item:)
    public static func failureInvalidAction(_ action: String, item: String) -> OpenHABSetSwitchStateIntentResponse {
        let intentResponse = OpenHABSetSwitchStateIntentResponse(code: .failureInvalidAction, userActivity: nil)
        intentResponse.action = action
        intentResponse.item = item
        return intentResponse
    }
}

#endif
