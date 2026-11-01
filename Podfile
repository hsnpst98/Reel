platform :ios, '16.4'

target 'Reel' do
  use_frameworks!
  pod 'MobileVLCKit', '~> 3.6'
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.4'
    end
  end
end
