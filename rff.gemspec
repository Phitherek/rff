Gem::Specification.new do |s|
	s.name = 'rff'
	s.version = '0.3.1'
	s.date = '2015-09-26'
	s.summary = 'A simple Ruby audio/video converter to HTML5 formats using FFmpeg'
	s.description = "This gem provides a simple Ruby interface to FFmpeg enabling users to convert audio and video to HTML5 supported formats and monitor the process as it goes."
	s.authors = ["Phitherek_"]
	s.email = "phitherek@gmail.com"
	s.files = ["lib/rff.rb", "lib/output_reader.rb", "lib/exceptions.rb", "lib/processor.rb", "lib/audio_handler.rb", "lib/video_handler.rb", "ext/rff/Makefile"]
	s.homepage = "https://github.com/Phitherek/rff"
	s.required_ruby_version = '>= 1.9.2'
	s.requirements << 'ffmpeg'
	s.requirements << 'make'
	s.extensions = ['ext/rff/extconf.rb']
	s.post_install_message = "The 0.2 version of rff has fixed a very important bug! Please do not use version 0.1 of this gem!"
end
