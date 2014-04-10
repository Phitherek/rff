require_relative 'processor'

# The main module for _rff_ -  a Ruby gem for simple audio and video conversion for HTML5 using FFmpeg
# Author:: Phitherek_ <phitherek [at] gmail [dot] com>
# License:: Open Source Software

module RFF
  
  # This class provides an "All audio to HTML5" conversion functionality. It takes every compatible with FFmpeg audio format and converts it to the three HTML5 audio formats - mp3, ogg and wav. If the input is already in one of these formats it is only converted to the two other formats, because it can be used as one of HTML5 sources.
  
  class AudioHandler
    
    # This constructor initializes the class with the following arguments:
    # * _input_ <b>(required)</b> - the full path to the input file
    # * <i>output_path</i> - a path to place the output file in. Defaults to nil, which means that the input' s directory path is used
    # * <i>custom_args</i> - passes custom arguments to FFmpeg. Defaults to nil, which means no custom arguments are given
    # * <i>recommended_audio_quality</i> - determines if recommended by FFmpeg community audio quality settings should be used. Defaults to true, which means audio conversion with good, recommended quality. Set to false if you are giving additional arguments that determine this quality.
    # * <i>disable_subtitles_decoding</i> - in some formats subtitle decoding causes problems. This option disables this feature. Defaults to true to bypass problems by default.
    # All of the arguments are passed on to underlying Processor instances. This method also determines input type, initializes processing percentage and creates needed Processor instances.
    
    def initialize input, output_path=nil, custom_args=nil, recommended_audio_quality=true, disable_subtitles_decoding=true
      @input = input
      @input_type = File.basename(@input).split(".")[1]
      @output_path = output_path
      @custom_args = custom_args
      @processing_percentage = 0
      @processors = []
      types = [:mp3, :ogg, :wav]
      if types.include?(@input_type.to_sym)
        types.delete(@input_type.to_sym)
      end
      types.each do |type|
        @processors << RFF::Processor.new(@input, type, @output_path, nil, @custom_args, recommended_audio_quality, disable_subtitles_decoding)
      end
    end
    
    # This method fires all the Processor instances (conversion processes) in a separate thread at once. Then it counts the overall processing percentage from all the Processor instances as the process goes and sets it to 100% on finish
    
    def fire_all
      @processing_thread = Thread.new do |th|
        begin
          @processors.each do |proc|
            proc.fire
            #sleep(5)
          end
          status = :processing
          while status != :done
            donecount = 0
            @processors.each do |proc|
              #puts "Process status:" + proc.status.to_s
              if proc.status == :completed || proc.status == :failed || proc.status == :aborted
                donecount = donecount + 1
              end
            end
            #puts "Done count: " + donecount.to_s
            if donecount == @processors.count
              status = :done
              break
            end
            processing_percentage = 0
            @processors.each do |proc|
              processing_percentage += proc.processing_percentage
            end
            @processing_percentage = (processing_percentage.to_f/@processors.count).to_i
          end
          @processing_percentage = 100
        rescue => e
          puts "Caught exception: " + e.to_s
          puts "Backtrace:"
          puts e.backtrace
          @status = :done
        end
      end
    end
    
    
    # This method fires all the Processor instances (conversion processes) in a separate thread sequentially - next Processor in the row is fired only after the Processor before finishes. It also counts the overall processing percentage from all the Processor instances as the process goes and sets it to 100% on finish
    
    def fire_sequential
      @processing_thread = Thread.new do |th|
        begin
          i = 0
          @processors.each do |proc|
            proc.fire
            sleep(1)
            while proc.status == :processing
              if proc.processing_percentage != nil
                @processing_percentage = (i*(100/@processors.count))+(proc.processing_percentage.to_f/@processors.count).to_i
              end
            end
            i = i+1
            #sleep(5)
          end
          @processing_percentage = 100
        rescue => e
          puts "Caught exception: " + e.to_s
          puts "Backtrace:"
          puts e.backtrace
          @status = :done
        end
      end
    end
    
    # This method kills all the processes in Processor instances and its own processing thread
    
    def killall
      @processors.each do |proc|
        proc.kill
      end
      @processing_thread.kill
    end
    
    # This method returns the "to MP3" Processor instance if it exists or nil otherwise
    
    def mp3_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :mp3
          ret = proc
        end
      end
      ret
    end
    
    # This method returns the "to OGG" Processor instance if it exists or nil otherwise
    
    def ogg_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :ogg
          ret = proc
        end
      end
      ret
    end
    
    # This method returns the "to WAV" Processor instance if it exists or nil otherwise
    
    def wav_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :wav
          ret = proc
        end
      end
      ret
    end
    
    # This method returns full input path
    
    def input
      @input
    end
    
    # This method returns full output file name
    
    def output_name
      @output_name
    end
    
    # This method returns the path in which output file is saved
    
    def output_path
      @output_path
    end
    
    # This method returns custom arguments passed to FFmpeg
    
    def custom_args
      @custom_args
    end
    
    # This method returns percentage of process completion
    
    def processing_percentage
      @processing_percentage || 0
    end
    
    # This method returns percentage of process completion formatted for output
    
    def format_processing_percentage
      @processing_percentage.nil? ? "0%" : @processing_percentage.to_s + "%"
    end
  end
end
