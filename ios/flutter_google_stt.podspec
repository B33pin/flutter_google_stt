#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_google_stt.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_google_stt'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for real-time speech-to-text using Google Cloud Speech-to-Text API.'
  s.description      = <<-DESC
A Flutter plugin for real-time speech-to-text using Google Cloud Speech-to-Text API via gRPC streaming.
Supports both Android and iOS platforms with native audio recording and streaming capabilities.
                       DESC
  s.homepage         = 'https://github.com/yourname/flutter_google_stt'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest for microphone usage
  s.resource_bundles = {'flutter_google_stt_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
