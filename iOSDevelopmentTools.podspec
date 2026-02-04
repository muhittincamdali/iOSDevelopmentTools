Pod::Spec.new do |s|
  s.name             = 'iOSDevelopmentTools'
  s.version          = '1.0.0'
  s.summary          = 'Essential development utilities and extensions for iOS.'
  s.description      = <<-DESC
    iOSDevelopmentTools provides essential development utilities and extensions
    for iOS. Features include debugging helpers, logging utilities, performance
    monitoring, memory leak detection, and developer productivity tools.
  DESC

  s.homepage         = 'https://github.com/muhittincamdali/iOSDevelopmentTools'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Muhittin Camdali' => 'contact@muhittincamdali.com' }
  s.source           = { :git => 'https://github.com/muhittincamdali/iOSDevelopmentTools.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  s.swift_versions = ['5.9', '5.10', '6.0']
  s.source_files = 'Sources/**/*.swift'
  s.frameworks = 'Foundation'
end
