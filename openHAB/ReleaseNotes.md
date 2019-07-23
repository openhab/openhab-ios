#  Release Notes

Migration from ObjectiveC to Swift.
Though this migration was as the start just a technical migration to a different programming language, it allowed to get the openhab iOS app out of a dead end and to come up to par with the development on other platforms and to be aligned with latest requirements on iOS.  

Addressing known issue and bugs:
* Setpoint got fixed, handles now decimals properly
* Sliders cells fixed to honor min, max and step, improved to show value that will be set on release
* Handling of images and videos got fixed 
* Maps: a default height is set, if none is given. Closes #184
* Icons are fixed - App is now able to handle png AND svg icons
* Long labels are correctly cut off 
* Accessibility improved by handling changes in font size
* Reworking the connection to remote myopenhab.org
* Search bar for items was added
* Authentication with mTLS client certificates
* Fixed handling push notifications
* Automated generation of screenshots

The excellent ObjectiveC code quality allowed the usage of the migration tool Swiftify for the body of the application. Still, internally a lot of changes were applied: 

* Unit tests were introduced. 
* JSON decoding was migrated to Decodable 
* Frameworks were upgraded to more recent versions
* Migrating to UNUserNotificationCenter
* Migration to built-in functionality of iOS, 
* Migrating to Swift 5 and Xcode 10.2
* Got rid of all compiler warnings - some remain in external frameworks (;-) 
* Swiftlinted source
* Got rid of trailing constraints in storyboard
* Addresses deprecations for instance NSAttributedString and Reachability
* Getting rid of last viewWithTag
* Cleaning up code commented out
* URL Strings composition migrated to Endpoint 
* Migration to logging framework os_log instead of print with typed access to UserDefaults.standard for string
* Migrated to os_log for logging

A watchOS app is in the making and will be released soon. 


