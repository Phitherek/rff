require 'open3'
Open3.popen2e("ruby output_writer.rb") do |procin, procout, procth|
  while !procout.eof?
    line = procout.gets
    puts line
    $stdout.flush
  end
  procth.join
  procin.close
  procout.close
end
