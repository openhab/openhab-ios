install! 'cocoapods', :generate_multiple_pod_projects => true, :incremental_installation => true

#platform :ios, '11.0'
#
use_frameworks!

target 'openHAB' do
    platform :ios, '11.0'
    pod 'SwiftFormat/CLI'
    pod 'SwiftLint'
    pod 'SVGKit'
    pod 'Firebase/Core'
    pod 'Fabric', '~> 1.7'
    pod 'Crashlytics', '~> 3.9'
    pod 'SwiftMessages'
    pod 'Fuzi', '~> 3.1'
    pod 'FlexColorPicker', :git => 'https://github.com/RastislavMirek/FlexColorPicker.git', :tag => '1.3.1'
    pod 'DynamicButton', '~> 6.2'
    pod 'SideMenu', '~> 6.4'
    pod 'Alamofire', '~> 4.0'
    pod 'Kingfisher', '~> 5.0'

    target 'openHABTestsSwift' do
        inherit! :search_paths
    end

end

target 'openHABUITests' do
    platform :ios, '11.0'
    inherit! :search_paths
end

target 'openHABWatchSwift Extension' do
    platform :watchos, '6.0'
    inherit! :search_paths
    pod 'Alamofire', '~> 4.0'
    pod 'Kingfisher/SwiftUI'
end

# Note: `pod install --clean-install` must be used if the post_install hook is changed
# temporary workaround for base language setting
post_install do |installer|
    installer.generated_projects.each do |project|
        project.root_object.known_regions = ["en", "Base"]
    end
end
