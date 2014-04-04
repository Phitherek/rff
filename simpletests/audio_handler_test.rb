require_relative '../lib/audio_handler'
ah = RFF::AudioHandler.new("testfile.wav")
ah.fire_all
while ah.processing_percentage == nil || ah.processing_percentage < 100
  if ah.mp3_processor != nil
    puts "MP3 status: " + ah.mp3_processor.format_processing_percentage
  end
  if ah.ogg_processor != nil
    puts "OGG status: " + ah.ogg_processor.format_processing_percentage
  end
  if ah.wav_processor != nil
    puts "WAV status: " + ah.wav_processor.format_processing_percentage
  end
  puts "Overall status: " + ah.format_processing_percentage
  sleep(1)
end
