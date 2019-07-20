install! 'cocoapods', :generate_multiple_pod_projects => true, :incremental_installation => true

platform :ios, '11.0'
use_frameworks!

target 'openHAB' do
    #pod 'AFNetworking', '~> 3.0'
    pod 'AFNetworking', '~> 2.6.0'
    pod 'SDWebImage', '~> 5.0' , :modular_headers => true
    pod 'SDWebImageSVGCoder'
    pod 'GDataXML-HTML', '~> 1.3.0'
    pod 'NKOColorPickerView', '~> 0.5'
    pod 'Firebase/Core'
    pod 'Fabric', '~> 1.7.2'
    pod 'Crashlytics', '~> 3.9.3'
    pod 'SwiftMessages'
    pod 'SideMenu', '~> 5.0'
end

target 'openHABTestsSwift' do
    inherit! :search_paths
    pod 'GDataXML-HTML', '~> 1.3.0'
    pod 'AFNetworking', '~> 2.6.0'
    #pod 'AFNetworking', '~> 3.0'
end
