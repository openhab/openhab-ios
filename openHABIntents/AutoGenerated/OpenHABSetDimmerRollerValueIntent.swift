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
@objc(OpenHABSetDimmerRollerValueIntent)
public class OpenHABSetDimmerRollerValueIntent: INIntent {
    @NSManaged public var item: String?
    @NSManaged public var value: NSNumber?
}

/*!
 @abstract Protocol to declare support for handling a OpenHABSetDimmerRollerValueIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(OpenHABSetDimmerRollerValueIntentHandling)
public protocol OpenHABSetDimmerRollerValueIntentHandling: NSObjectProtocol {
    /*!
     @abstract Handling method - Execute the task represented by the OpenHABSetDimmerRollerValueIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a OpenHABSetDimmerRollerValueIntentResponse containing the details of the result of having executed the intent

     @see  OpenHABSetDimmerRollerValueIntentResponse
     */
    @objc(handleSetDimmerRollerValue:completion:)
    func handle(intent: OpenHABSetDimmerRollerValueIntent, completion: @escaping (OpenHABSetDimmerRollerValueIntentResponse) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(handleSetDimmerRollerValue:completion:)
    func handle(intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABSetDimmerRollerValueIntentResponse

    /*!
     @abstract Dynamic options methods - provide options for the parameter at runtime
     @discussion Called to query dynamic options for the parameter and this intent in its current form.

     @param  intent The input intent
     @param  completion The response block contains options for the parameter
     */
    @available(iOS 14.0, macOS 10.16, watchOS 7.0, *)
    @objc(provideItemOptionsCollectionForSetDimmerRollerValue:withCompletion:)
    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(provideItemOptionsCollectionForSetDimmerRollerValue:withCompletion:)
    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent) async throws -> INObjectCollection<NSString>

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a OpenHABSetDimmerRollerValueIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see OpenHABSetDimmerRollerValueIntentResponse
     */
    @objc(confirmSetDimmerRollerValue:completion:)
    optional func confirm(intent: OpenHABSetDimmerRollerValueIntent, completion: @escaping (OpenHABSetDimmerRollerValueIntentResponse) -> Swift.Void)

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    @objc(confirmSetDimmerRollerValue:completion:)
    optional func confirm(intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABSetDimmerRollerValueIntentResponse

    /*!
     @abstract Default values for parameters with dynamic options
     @discussion Called to query the parameter default value.
     */
    @available(iOS 14.0, macOS 10.16, watchOS 7.0, *)
    @objc(defaultItemForSetDimmerRollerValue:)
    optional func defaultItem(for intent: OpenHABSetDimmerRollerValueIntent) -> String?

    /*!
     @abstract Deprecated dynamic options methods.
     */
    @available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
    @available(watchOS, introduced: 6.0, deprecated: 7.0, message: "")
    @objc(provideItemOptionsForSetDimmerRollerValue:withCompletion:)
    optional func provideItemOptions(for intent: OpenHABSetDimmerRollerValueIntent, with completion: @escaping ([String]?, Error?) -> Swift.Void)
}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum OpenHABSetDimmerRollerValueIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
    case failureInvalidItem = 100
    case failureEmptyValue
    case failureInvalidValue
}

@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(OpenHABSetDimmerRollerValueIntentResponse)
public class OpenHABSetDimmerRollerValueIntentResponse: INIntentResponse {
    @NSManaged public var item: String?
    @NSManaged public var value: NSNumber?

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc public fileprivate(set) var code: OpenHABSetDimmerRollerValueIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    public convenience init(code: OpenHABSetDimmerRollerValueIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

    /*!
     @abstract Initializes and returns the response object with the success code.
     */
    @objc(successIntentResponseWithValue:item:)
    public static func success(value: NSNumber, item: String) -> OpenHABSetDimmerRollerValueIntentResponse {
        let intentResponse = OpenHABSetDimmerRollerValueIntentResponse(code: .success, userActivity: nil)
        intentResponse.value = value
        intentResponse.item = item
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failureInvalidItem code.
     */
    @objc(failureInvalidItemIntentResponseWithItem:)
    public static func failureInvalidItem(_ item: String) -> OpenHABSetDimmerRollerValueIntentResponse {
        let intentResponse = OpenHABSetDimmerRollerValueIntentResponse(code: .failureInvalidItem, userActivity: nil)
        intentResponse.item = item
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failureEmptyValue code.
     */
    @objc(failureEmptyValueIntentResponseWithItem:)
    public static func failureEmptyValue(item: String) -> OpenHABSetDimmerRollerValueIntentResponse {
        let intentResponse = OpenHABSetDimmerRollerValueIntentResponse(code: .failureEmptyValue, userActivity: nil)
        intentResponse.item = item
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failureInvalidValue code.
     */
    @objc(failureInvalidValueIntentResponseWithValue:item:)
    public static func failureInvalidValue(_ value: NSNumber, item: String) -> OpenHABSetDimmerRollerValueIntentResponse {
        let intentResponse = OpenHABSetDimmerRollerValueIntentResponse(code: .failureInvalidValue, userActivity: nil)
        intentResponse.value = value
        intentResponse.item = item
        return intentResponse
    }
}

#endif
