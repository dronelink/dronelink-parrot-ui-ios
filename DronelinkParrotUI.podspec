Pod::Spec.new do |s|
  s.name = "DronelinkParrotUI"
  s.version = "1.0.0"
  s.summary = "Dronelink Parrot UI components"
  s.homepage = "https://dronelink.com/"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.author = { "Dronelink" => "dev@dronelink.com" }
  s.swift_version = "5.0"
  s.platform = :ios
  s.ios.deployment_target  = "12.0"
  s.source = { :git => "https://github.com/dronelink/dronelink-parrot-ui-ios.git", :tag => "#{s.version}" }
  s.source_files  = "DronelinkParrotUI/**/*.swift"
  s.resources = "DronelinkParrotUI/**/*.{strings,xcassets}"

  s.dependency "DronelinkCore", "~> 1.6.0"
  s.dependency "DronelinkCoreUI", "~> 1.4.0"
  s.dependency "DronelinkParrot", "~> 1.0.0"
  s.dependency "SnapKit", "~> 5.0.1"
  s.dependency "MaterialComponents/Palettes", "~> 109.2.0"
end

