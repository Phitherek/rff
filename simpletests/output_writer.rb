$stdout.sync = true
puts "Writing some output..."
puts "In lines..."
sleep(1)
puts "And now, let' s try with CR!"
print "Process completion: 0%"
sleep(1)
print "\rProcess completion: 20%"
sleep(3)
print "\rProcess completion: 80%"
sleep(1)
print "\rProcess completion: 100%\n"
