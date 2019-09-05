install! 'cocoapods', :generate_multiple_pod_projects => true, :incremental_installation => true

platform :ios, '11.0'
use_frameworks!

target 'openHAB' do
    pod 'SVGKit'
    pod 'Firebase/Core'
    pod 'Fabric', '~> 1.7.2'
    pod 'Crashlytics', '~> 3.9.3'
    pod 'SwiftMessages'
    pod 'SideMenu', '~> 5.0'
    pod 'FlexColorPicker'
    pod 'DynamicButton', '~> 6.2'
    pod 'Alamofire', '~> 4.0'
    pod 'Fuzi', '~> 3.1'
    pod 'Kingfisher', '~> 5.0'
end

target 'openHABTestsSwift' do
    inherit! :search_paths
    pod 'Alamofire', '~> 4.0'
    pod 'Fuzi', '~> 3.1'
end
