Gem::Specification.new do |s|
  s.name = 'v2av'
  s.version = '0.1.1'
  s.summary = 'Adds subtitles + TTS voiceover to video.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/v2av.rb']
  s.add_runtime_dependency('subunit', '~> 0.4', '>=0.4.0')
  s.add_runtime_dependency('ruby-ogginfo', '~> 0.7', '>=0.7.2')
  s.add_runtime_dependency('wavefile', '~> 1.1', '>=1.1.0')
  s.add_runtime_dependency('archive-zip', '~> 0.12', '>=0.12.0')
  s.add_runtime_dependency('pollyspeech', '~> 0.2', '>=0.2.0')
  s.signing_key = '../privatekeys/v2av.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/v2av'
end
