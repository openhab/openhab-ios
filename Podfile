install! 'cocoapods', :generate_multiple_pod_projects => true, :incremental_installation => true

#platform :ios, '11.0'
#
use_frameworks!

def shared_pods
    pod 'Alamofire', '~> 4.0'
    pod 'Fuzi', '~> 3.1'
end

target 'openHAB' do
    platform :ios, '11.1'
    shared_pods
    pod 'SwiftFormat/CLI'
    pod 'SwiftLint'
    pod 'SVGKit'
    pod 'Firebase/Core'
    pod 'Fabric', '~> 1.7'
    pod 'Crashlytics', '~> 3.9'
    pod 'SwiftMessages'
    pod 'FlexColorPicker', :git => 'https://github.com/RastislavMirek/FlexColorPicker.git', :tag => '1.3.1'
    pod 'DynamicButton', '~> 6.2'
    pod 'SideMenu', '~> 6.4'
    pod 'Kingfisher', '~> 5.0'

    target 'openHABTestsSwift' do
        inherit! :search_paths
    end

end

target 'openHABUITests' do
    platform :ios, '11.1'
    inherit! :search_paths
end

target 'OpenHABCore' do
    platform :ios, '11.1'
    shared_pods
    pod 'Kingfisher', '~> 5.0'
end

target 'OpenHABCoreWatch' do
    platform :watchos, '6.0'
    shared_pods
    pod 'Kingfisher/SwiftUI', '~> 5.0'
end

target 'openHABWatchSwift Extension' do
    platform :watchos, '6.0'
    inherit! :search_paths
    shared_pods
    pod 'Kingfisher/SwiftUI', '~> 5.0'
    pod 'DeviceKit', '~> 2.0'
end

# Note: `pod install --clean-install` must be used if the post_install hook is changed
post_install do |installer|
    # temporary workaround for base language setting
    installer.generated_projects.each do |project|
        project.root_object.known_regions = ["en", "Base"]
    end

    # workaround for https://github.com/CocoaPods/CocoaPods/issues/9135
    watchPods = ['Alamofire-watchOS', 'Kingfisher-watchOS', 'Fuzi-watchOS']
    installer.generated_projects.each do |project|
        project.targets.each do |target|
            next unless watchPods.include? target.name

            target.build_configurations.each do |config|
                config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}.${PLATFORM_NAME}'
            end
        end
    end
end
