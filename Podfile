install! 'cocoapods', :generate_multiple_pod_projects => true, :incremental_installation => true

platform :ios, '11.0'
use_frameworks!

target 'openHAB' do
    pod 'SwiftFormat/CLI'
    pod 'SwiftLint'
    pod 'SVGKit'
    pod 'Firebase/Core'
    pod 'Fabric', '~> 1.7.2'
    pod 'Crashlytics', '~> 3.9.3'
    pod 'SwiftMessages'
    pod 'FlexColorPicker'
    pod 'Fuzi', '~> 3.1'
end

target 'openHABTestsSwift' do
    inherit! :search_paths
    pod 'Fuzi', '~> 3.1'
end
