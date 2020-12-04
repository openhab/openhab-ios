source 'https://github.com/CocoaPods/Specs.git'

install! 'cocoapods', :generate_multiple_pod_projects => true, :incremental_installation => true
inhibit_all_warnings!
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
    pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :branch => '3.x'
    pod 'Firebase/Crashlytics'
    pod 'SwiftMessages'
    pod 'FlexColorPicker'
    pod 'DynamicButton', '~> 6.2'
    pod 'SideMenu', '~> 6.4'
    pod 'Kingfisher', '~> 5.0'
    pod 'AlamofireNetworkActivityIndicator', '~> 2.4'

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

target 'openHABWatch Extension' do
    platform :watchos, '6.0'
    inherit! :search_paths
    shared_pods
    pod 'Kingfisher/SwiftUI', '~> 5.0'
    pod 'DeviceKit', '~> 4.0'
end

target 'openHABIntents' do
    platform :ios, '11.1'
    shared_pods
    pod 'Kingfisher', '~> 5.0'
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

    # workaround for Xcode 12 warnings
    installer.generated_projects.each do |project|
        project.root_object.attributes['LastUpgradeCheck'] = 1220
        project.build_configurations.each do |config|
            if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] == '8.0' || config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] == '8'
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
            end
        end

        user_data_dir = Xcodeproj::XCScheme.user_data_dir(project.path)
        project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
                scheme_filename = "#{user_data_dir}/#{target}.xcscheme"
                `sed -i '' 's/LastUpgradeVersion = \"1100\"/LastUpgradeVersion = \"1220\"/' "#{scheme_filename}"`
            end
        end
    end
end

post_integrate do |installer|
    if defined?(installer.pods_project.path)
        pbxproj_file = "#{installer.pods_project.path}/project.pbxproj"
        `sed -i '' 's/LastUpgradeCheck = 1100/LastUpgradeCheck = 1220/' "#{pbxproj_file}"`
    end
end
