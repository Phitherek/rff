require 'open3'
require "../lib/output_reader.rb"

Open3.popen2e("ffmpeg -y -i testfile.wav -acodec libvorbis testfile.ogg") do |progin, progout, progthread|
  i = 0
  rd = RFF::OutputReader.new(progout)
  begin
    line = rd.gets ["\n", "\r"]
    line = line.chomp! if !line.nil?
    if !line.nil? && line != "EOF"
      i = i+1
      puts i.to_s + " " + line
      $stdout.flush
    end
  end while line != "EOF"
  progout.close
  progin.close
  puts "Exit status: " + progthread.value.to_s
end
