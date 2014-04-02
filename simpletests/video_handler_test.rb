require_relative '../lib/video_handler'
vh = RFF::VideoHandler.new("testvid.ogv")
vh.fire_sequential
while vh.processing_percentage == nil || vh.processing_percentage < 100
  if vh.webm_processor != nil
    puts "WEBM status: " + vh.webm_processor.format_processing_percentage
  end
  if vh.ogv_processor != nil
    puts "OGV status: " + vh.ogv_processor.format_processing_percentage
  end
  if vh.mp4_processor != nil
    puts "MP4 status: " + vh.mp4_processor.format_processing_percentage
  end
  puts "Overall status: " + vh.format_processing_percentage
  sleep(1)
end
