module RFF
  class OutputReader
    @@buffer = ""
    @@writecount = 0
    @@readcount = 0
    def initialize io
      @eof = false
      @reading_thread = Thread.new do |th|
        while data = io.read(10)
          @@buffer += data
          @@writecount += data.length
        end
        @eof = true
      end
    end
    
    def gets seps=["\n"]
      if @@writecount > @@readcount
        line = ""
        begin
          c = @@buffer[@@readcount]
          if !c.nil?
            @@readcount = @@readcount+1
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
    
    def join_reading_thread
      @reading_thread.join 
    end
    
    def get_raw_buffer
      @@buffer
    end
  end
end
