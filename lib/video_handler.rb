require_relative 'processor'
require 'fileutils'

module RFF

  # This class provides an "All video to HTML5" conversion functionality. It takes every compatible with FFmpeg video format and converts it to the three HTML5 video formats - mp4, ogv and webm. If the input is already in one of these formats it is only converted to the two other formats and the original file is copied to the output directory, because it can be used as one of HTML5 sources.

  class VideoHandler

    # This constructor initializes the class with the following arguments:
    # * _input_ <b>(required)</b> - the full path to the input file
    # * <i>output_path</i> - a path to place the output file in. Defaults to nil, which means that the input' s directory path is used
    # * _quality_ - only affects video conversion. Sets the video conversion quality. Defaults to 5000k, which is tested value for good video conversion quality
    # * <i>custom_args</i> - passes custom arguments to FFmpeg. Defaults to nil, which means no custom arguments are given
    # * <i>recommended_audio_quality</i> - determines if recommended by FFmpeg community audio quality settings should be used. Defaults to true, which means audio conversion with good, recommended quality. Set to false if you are giving additional arguments that determine this quality.
    # * <i>disable_subtitles_decoding</i> - in some formats subtitle decoding causes problems. This option disables this feature. Defaults to true to bypass problems by default.
    # All of the arguments are passed on to underlying Processor instances. This method also determines input type, initializes processing percentage and creates needed Processor instances.

    def initialize input, output_path=nil, quality="5000k", custom_args=nil, recommended_audio_quality=true, disable_subtitles_decoding=true
      @input = input
      @input_type = File.basename(@input).split(".")[1]
      @output_path = output_path
      @quality = quality
      @custom_args = custom_args
      @processing_percentage = 0
      @processors = []
      types = [:mp4, :ogv, :webm]
      if !@output_path.nil? && !File.exists?(@output_path)
          FileUtils.mkdir_p(@output_path)
      end
      if types.include?(@input_type.to_sym)
        types.delete(@input_type.to_sym)
        if !@output_path.nil?
            FileUtils.cp @input, @output_path
        end
      end
      types.each do |type|
        @processors << RFF::Processor.new(@input, type, @output_path, @quality, @custom_args, recommended_audio_quality, disable_subtitles_decoding)
      end
      @handler_status = :ready
    end

    # This method fires all the Processor instances (conversion processes) in a separate thread at once. Then it counts the overall processing percentage from all the Processor instances as the process goes and sets it to 100% on finish

    def fire_all
      @processing_thread = Thread.new do |th|
        begin
          @processors.each do |proc|
            proc.fire
            #sleep(5)
          end
          @handler_status = :processing
          status = :processing
          while status != :done
            donecount = 0
            @processors.each do |proc|
              #puts "Process status:" + proc.status.to_s
              if (!proc.command_exit_status.nil? && (proc.status == :completed || proc.status == :failed)) || proc.status == :aborted
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
          @processors.each do |proc|
              if proc.status != :completed
                  @handler_status = :failed
                  break
              end
          end
          if @handler_status != :failed
              @handler_status = :completed
          end
          @processing_percentage = 100
        rescue => e
          puts "Caught exception: " + e.to_s
          puts "Backtrace:"
          puts e.backtrace
          status = :done
          @handler_status = :failed
        end
      end
    end

    # This method fires all the Processor instances (conversion processes) in a separate thread sequentially - next Processor in the row is fired only after the Processor before finishes. It also counts the overall processing percentage from all the Processor instances as the process goes and sets it to 100% on finish

    def fire_sequential
      @processing_thread = Thread.new do |th|
        begin
          i = 0
          @handler_status = :processing
          @processors.each do |proc|
            proc.fire
            sleep(1)
            while proc.command_exit_status.nil? || proc.status == :processing && proc.status != :aborted
              if proc.processing_percentage != nil
                @processing_percentage = (i*(100/@processors.count))+(proc.processing_percentage.to_f/@processors.count).to_i
              end
            end
            i = i+1
            #sleep(5)
          end
          @processors.each do |proc|
              if proc.status != :completed
                  @handler_status = :failed
                  break
              end
          end
          if @handler_status != :failed
              @handler_status = :completed
          end
          @processing_percentage = 100
        rescue => e
          puts "Caught exception: " + e.to_s
          puts "Backtrace:"
          puts e.backtrace
          status = :done
          @handler_status = :failed
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

    # This method returns the "to MP4" Processor instance if it exists or nil otherwise

    def mp4_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :mp4
          ret = proc
        end
      end
      ret
    end

    # This method returns the "to OGV" Processor instance if it exists or nil otherwise

    def ogv_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :ogv
          ret = proc
        end
      end
      ret
    end

    # This method returns the "to WEBM" Processor instance if it exists or nil otherwise

    def webm_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :webm
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

    # This method returns used video quality

    def quality
      @quality
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
