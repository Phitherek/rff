require 'mkmf'

fffound = find_executable('ffmpeg')
makefound = find_executable('make')

if !fffound
  puts "FFmpeg was not found on your system, installation will be aborted. Please install FFmpeg and try again."
  return false
end

if !makefound
  puts "Make was not found on your system, installation will be aborted. Please install Make and try again."
  return false
end

puts "Dependencies OK, proceeding with the installation..."

File.new(Dir.pwd + '/rff.' + RbConfig::CONFIG['DLEXT'], "w+")

$makefile_created = true
