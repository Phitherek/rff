Gem::Specification.new do |s|
	s.name = 'rff'
	s.version = '0.1'
	s.date = '2014-04-02'
	s.summary = 'A simple Ruby audio/video converter to HTML5 formats using FFmpeg'
	s.description = "This gem provides a simple Ruby interface to FFmpeg enabling users to convert audio and video to HTML5 supported formats and monitor the process as it goes."
	s.authors = ["Phitherek_"]
	s.email = "phitherek@gmail.com"
	s.files = ["lib/rff.rb", "lib/output_reader.rb", "lib/exceptions.rb", "lib/processor.rb", "lib/audio_handler.rb", "lib/video_handler.rb"]
	s.homepage = "https://github.com/Phitherek/rff"
end
