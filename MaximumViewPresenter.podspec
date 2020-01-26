
Pod::Spec.new do |s|

  s.name         = "MaximumViewPresenter"
  s.version      = "0.0.1"
  s.summary      = "A MVP implementation"
  s.homepage     = "https://bitbucket.org/iosmax/maximumviewpresenter/src/master/"
  s.license      = "Copyright (c) 2020 Maxime Boulat"
  s.author             = { "Maxime Boulat" => "" }
  s.source       = { :git => "https://iosmax@bitbucket.org/iosmax/maximumviewpresenter.git", :tag => "#{s.version}" }
  s.source_files  = "MaximumViewPresenter/*.{h, swift}"
  s.exclude_files = "Classes/Exclude"
  s.requires_arc = true

  # s.dependency "JSONKit", "~> 1.4"

end
