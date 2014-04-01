require 'spec_helper'

describe RFF::Processor do
  it 'should validate arguments' do
    lambda{ RFF::Processor.new(nil, :mp3) }.should raise_error(RFF::ArgumentError)
    lambda{ RFF::Processor.new("", :mp3) }.should raise_error(RFF::ArgumentError)
    lambda{ RFF::Processor.new("jrifrijf", nil) }.should raise_error(RFF::ArgumentError)
    lambda{ RFF::Processor.new("jrijefjie", :thing) }.should raise_error(RFF::ArgumentError)
    lambda{ RFF::Processor.new("ejeiwjei.ext", :mp3)}.should_not raise_error
  end
  
  it 'should have correct field values on initialize' do
    @processor = RFF::Processor.new("costam.ext", :mp3)
    @processor.input.should eq("costam.ext")
    @processor.output_type.should eq(:mp3)
    @processor.output_name.should eq("costam")
    @processor.output_path.should eq(".")
    @processor.quality.should eq("5000k")
    @processor.custom_args.should be_nil
    @processor = RFF::Processor.new("/some/path/costam.ext", :mp3)
    @processor.input.should eq("/some/path/costam.ext")
    @processor.output_type.should eq(:mp3)
    @processor.output_name.should eq("costam")
    @processor.output_path.should eq("/some/path")
    @processor.quality.should eq("5000k")
    @processor.custom_args.should be_nil
    @processor = RFF::Processor.new("/some/path/costam.ext", :mp3, "/some/other/path", "4000k", "-customoption value")
    @processor.input.should eq("/some/path/costam.ext")
    @processor.output_type.should eq(:mp3)
    @processor.output_name.should eq("costam")
    @processor.output_path.should eq("/some/other/path")
    @processor.quality.should eq("4000k")
    @processor.custom_args.should eq("-customoption value")
  end
  
  it 'should detect conversion type by output type' do
    @processor = RFF::Processor.new("ejfeijfie", :mp3)
    @processor.conversion_type.should eq(:audio)
    @processor = RFF::Processor.new("ejfeijfie", :mp4)
    @processor.conversion_type.should eq(:video)
  end
  
  it 'should generate correct FFmpeg commands' do
    @processor = RFF::Processor.new("costam", :mp3)
    @processor.command.should eq("ffmpeg -y -i costam -acodec libmp3lame ./costam.mp3")
    @processor = RFF::Processor.new("costam.ext", :ogg, nil, "5000k", "-someoption value")
    @processor.command.should eq("ffmpeg -y -i costam.ext -acodec libvorbis -someoption value ./costam.ogg")
    @processor = RFF::Processor.new("/some/path/costam.ext", :wav)
    @processor.command.should eq("ffmpeg -y -i /some/path/costam.ext -acodec pcm_s16le /some/path/costam.wav")
    @processor = RFF::Processor.new("/some/path/costam.ext", :webm, "/some/other/path")
    @processor.command.should eq("ffmpeg -y -i /some/path/costam.ext -acodec libvorbis -vcodec libvpx -b:v 5000k /some/other/path/costam.webm")
    @processor = RFF::Processor.new("/some/path/costam.ext", :ogv, "/some/other/path", "4000k", "-someoption value")
    @processor.command.should eq("ffmpeg -y -i /some/path/costam.ext -acodec libvorbis -vcodec libtheora -b:v 4000k -someoption value /some/other/path/costam.ogv")
    @processor = RFF::Processor.new("/some/path/costam.ext", :mp4)
    @processor.command.should eq("ffmpeg -y -i /some/path/costam.ext -acodec aac -vcodec mpeg4 -strict -2 -b:v 5000k /some/path/costam.mp4")
  end
  
  it 'should generate correct full output path' do
    @processor = RFF::Processor.new("/some/path/costam.ext", :mp3)
    @processor.full_output_path.should eq("/some/path/costam.mp3")
    @processor = RFF::Processor.new("/some/path/costam.ext", :mp3, "/some/other/path")
    @processor.full_output_path.should eq("/some/other/path/costam.mp3")
  end
end
