require 'open3'
require '../lib/output_reader.rb'
Open3.popen2e("ruby output_writer.rb") do |procin, procout, procth|
  rd = RFF::OutputReader.new(procout)
  line = ""
  i = 0
  begin
    line = rd.gets ["\n", "\r"]
    line = line.chomp! if !line.nil?
    if !line.nil? && line != "EOF"
      i = i+1
      puts i.to_s + " " + line
      $stdout.flush
    end
  end while line != "EOF"
  rd.join_reading_thread
  procin.close
end
