#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint alarm_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'alarm_plus'
  s.version          = '0.1.0'
  s.summary          = 'Reliability-first cross-platform alarm plugin for Flutter.'
  s.description      = <<-DESC
Reliability-first cross-platform alarm plugin for Flutter:
Android exact alarms with foreground ringing service,
iOS best-effort notification alarms.
                       DESC
  s.homepage         = 'https://github.com/pratikbharad/gps_alarm/tree/main/alarm_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'alarm_plus' => 'maintainers@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'alarm_plus_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
