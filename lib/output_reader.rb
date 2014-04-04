module RFF
  
  # A class that reads the given IO stream and provides advanced reading functions for it. It reads the given stream to the internal buffer in separate thread and uses this buffer to provide reading functionality that is not available in IO stream alone
  
  class OutputReader
    
    # This constructor initializes the class instance with IO stream and starts the stream reading thread
    # * _io_ - the IO stream to read from
    
    def initialize io
      @buffer = ""
      @writecount = 0
      @readcount = 0
      @eof = false
      @reading_thread = Thread.new do |th|
        while data = io.read(10)
          @buffer += data
          @writecount += data.length
        end
        @eof = true
      end
    end
    
    # This method provides an implementation of IO gets method for streams containing lines with different line separators in some parts
    # * _seps_ - an array defining the line separators. Defaults to one, default LF separator
    # Outputs next line from the stream or "EOF\\n" when the stream reaches its end
    
    def gets seps=["\n"]
      if @writecount > @readcount
        line = ""
        begin
          c = @buffer[@readcount]
          if !c.nil?
            @readcount = @readcount+1
            line += c
            if seps.include?(c)
              break
            end
          end
        end while !@eof
        line
      elsif @eof
        "EOF\n"
      else
        nil
      end
    end
    
    # This method can be used to join the reading thread in some place of the script
    
    def join_reading_thread
      @reading_thread.join 
    end
    
    # This method outputs the internal buffer without any additional processing
    
    def get_raw_buffer
      @buffer
    end
  end
end
