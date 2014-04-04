require_relative 'exceptions'
require_relative 'output_reader'
require 'open3'
require 'time'
module RFF
  
  # The main processing class of the _rff_ gem. It spawns FFmpeg conversion process and parses its output, providing information about input and output files and current process status
  
  class Processor
    
    # This constructor initializes the class with the following arguments:
    # * _input_ <b>(required)</b> - the full path to the input file
    # * <i>output_type</i> <b>(required)</b> - defines the type of the output. Must be one of [:mp3, :ogg, :wav] for audio conversion or [:mp4, :ogv, :webm] for video conversion
    # * <i>output_path</i> - a path to place the output file in. Defaults to nil, which means that the input' s directory path is used
    # * _quality_ - only affects video conversion. Sets the video conversion quality. Defaults to 5000k, which is tested value for good video conversion quality
    # * <i>custom_args</i> - passes custom arguments to FFmpeg. Defaults to nil, which means no custom arguments are given
    # * <i>recommended_audio_quality</i> - determines if recommended by FFmpeg community audio quality settings should be used. Defaults to true, which means audio conversion with good, recommended quality. Set to false if you are giving additional arguments that determine this quality.
    # This method also validates arguments, determines full output name, generates appropriate FFmpeg command, determines conversion type and initializes status (it is :pending at this point).
    
    def initialize input, output_type, output_path=nil, quality="5000k", custom_args=nil, recommended_audio_quality=true
      if input.nil? || input.empty? || output_type.nil?
        raise RFF::ArgumentError.new("Input and output type can not be empty nor nil!")
      end
      if ![:mp3, :ogg, :wav, :mp4, :webm, :ogv].include?(output_type.to_sym)
        raise RFF::ArgumentError.new("Output type must be one of [:mp3, :ogg, :wav, :mp4, :webm, :ogv]!")
      end
      @input = input
      @output_type = output_type
      @output_name = File.basename(@input).split(".")[0]
      @output_path = output_path || File.dirname(input)
      @quality = quality
      @custom_args = custom_args
      if [:mp3, :ogg, :wav].include?(@output_type)
        @command = "ffmpeg -y -i #{@input} -acodec #{@output_type == :mp3 ? "libmp3lame" : (@output_type == :ogg ? "libvorbis" : "pcm_s16le")}#{recommended_audio_quality ? (@output_type == :mp3 ? " -aq 2" : (@output_type == :ogg ? " -aq 4" : "")) : ""}#{@custom_args.nil? ? "" : " #{@custom_args}"} #{@output_path}/#{@output_name}.#{@output_type.to_s}"
        @conversion_type = :audio
      else
        @command = "ffmpeg -y -i #{@input} -acodec #{(@output_type == :webm || @output_type == :ogv) ? "libvorbis" : "aac"} -vcodec #{@output_type == :webm ? "libvpx" : (@output_type == :ogv ? "libtheora" : "mpeg4")}#{@output_type == :mp4 ? " -strict -2" : ""}#{(!@quality.nil? && !@quality.empty?) ? " -b:v #{@quality}" : ""}#{recommended_audio_quality ? (@output_type == :webm || @output_type == :ogv ? " -aq 4" : " -b:a 240k") : ""}#{@custom_args.nil? ? "" : " #{@custom_args}"} #{@output_path}/#{@output_name}.#{@output_type.to_s}"
        @conversion_type = :video
      end
      @status = :pending
    end
    
    # This method runs the FFmpeg conversion process in a separate thread. First it initializes processing percentage and then spawns a new thread, in which FFmpeg conversion process is spawned through Open3.popen2e. It sets the processing status, passes the command output to OutputReader instance and initializes all the needed structures for information. Then it parses the output until it ends to extract the information, which is available through this class' getter methods. All the information is filled in as soon as it appears in the command output. When the process finishes, it cleans up the streams, sets percentage to 100% and gets the command' s exit status. Then it sets :completed or :failed status according to the command' s status. At the end it catches and displays any exceptions that can occur in the thread
    
    def fire
      @processing_percentage = 0
      @processing_thread = Thread.new do |th|
        begin
          Open3.popen2e(@command) do |progin, progout, progthread|
            @status = :processing
            @parser_status = :normal
            outputreader = OutputReader.new(progout)
            @rawoutput = []
            @input_meta_common = {}
            @input_meta_audio = {}
            @input_meta_video = {}
            @output_meta_common = {}
            @output_meta_audio = {}
            @output_meta_video = {}
            @processing_status = {}
            begin
              #puts "DEBUG: Processing next line..."
              line = outputreader.gets(["\n", "\r"])
              line = line.chomp! if !line.nil?
              #puts "DEBUG: Line: " + line.to_s
              #puts "DEBUG: Raw OutputReader buffer content: "
              #puts outputreader.get_raw_buffer
              if !line.nil? && line != "EOF"
                #puts "DEBUG: Adding line to rawoutput..."
                @rawoutput << line
                # Getting rid of unnecessary indentation spaces
                #puts "DEBUG: Removing unnecessary spaces..."
                if line[/^[ ]+/] != nil
                  line[/^[ ]+/] = ""
                end
                if line[/[ ]+/] != nil
                  line[/[ ]+/] = " "
                end
                if line[/[ ]+$/] != nil
                  line[/[ ]+$/] = ""
                end
                line.gsub!(/=[ ]+/, "=")
                # Parsing
                #puts "DEBUG: Line after spaces removal: " + line.to_s
                #puts "DEBUG: Parsing line..."
                if @conversion_type == :audio
                  if @parser_status == :meta
                    #puts "DEBUG: Parser in metadata parsing mode"
                    if line[0..7] == "Duration" || line[0..5] == "Stream" || line[0] == "[" || line[0..5] == "Output" || line[0..4] == "Input" 
                      @parser_status = :normal
                    else
                      #puts "DEBUG: Reading metadata line..."
                      if @last_met_io == :input
                        @input_meta_audio[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                      elsif @last_met_io == :output
                        @output_meta_audio[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                      end
                    end
                  end
                  if @parser_status == :strmap
                    #puts "DEBUG: Parser in stream mapping parsing mode"
                    #puts "DEBUG: Reading stream mapping information..."
                    @stream_mapping_audio = line[21..-2]
                    @parser_status = :retnormal
                  end
                  if @parser_status == :normal
                    #puts "DEBUG: Parser in normal mode"
                    if line[0..5] == "ffmpeg"
                      #puts "DEBUG: Approached version line"
                      @ff_versionline = line
                    elsif line[0..4] == "built"
                      #puts "DEBUG: Approached build line"
                      @ff_buildline = line
                    elsif line[0..4] == "Input"
                      #puts "DEBUG: Approached input declaration"
                      @input_type = line.split(",")[1][1..-1]
                      @last_met_io = :input
                    elsif line[0..5] == "Output"
                      #puts "DEBUG: Approached output declaration"
                      @detected_output_type = line.split(",")[1][1..-1]
                      @last_met_io = :output
                    elsif line == "Metadata:"
                      #puts "DEBUG: Approached metadata start"
                      @parser_status = :meta
                    elsif line[0..7] == "Duration"
                      #puts "DEBUG: Approached duration line"
                      @input_duration = line.split(",")[0][10..-1]
                      if line.split(",")[1][1..5] == "start"
                        #puts "DEBUG: Detected start variation of the line"
                        @input_start = line.split(",")[1][6..-1]
                        @input_bitrate = line.split(",")[2][10..-1]
                      else
                        #puts "DEBUG: Detected only bitrate variation of the line"
                        @input_bitrate = line.split(",")[1][10..-1]
                      end
                    elsif line == "Stream mapping:"
                      #puts "DEBUG: Approached stream mapping declaration"
                      @parser_status = :strmap
                    elsif line[0..5] == "Stream"
                      #puts "DEBUG: Approached stream information line"
                      if @last_met_io == :input
                        @audio_input_format = line.split(",")[0][20..-1]
                        @audio_input_freq = line.split(",")[1][1..-1]
                        @audio_input_channelmode = line.split(",")[2][1..-1]
                        @audio_input_format_type = line.split(",")[3][1..-1]
                        if line.split(",")[4] != nil
                          @audio_input_bitrate2 = line.split(",")[4][1..-1]
                        end
                      elsif @last_met_io == :output
                        @audio_output_format = line.split(",")[0][20..-1]
                        @audio_output_freq = line.split(",")[1][1..-1]
                        @audio_output_channelmode = line.split(",")[2][1..-1]
                        @audio_output_format_type = line.split(",")[3][1..-1]
                        if line.split(",")[4] != nil
                          @audio_output_bitrate2 = line.split(",")[4][1..-1]
                        end
                      end
                    elsif line[0..3] == "size"
                      #puts "DEBUG: Approached processing status line"
                      line.split(" ").each do |spl|
                        @processing_status[spl.split("=")[0].to_sym] = spl.split("=")[1]
                      end
                      if @processing_status[:time] != nil && @input_duration != nil
                        @processing_percentage = ((((Time.parse(@processing_status[:time])-Time.parse("0:0"))/(Time.parse(@input_duration)-Time.parse("0:0")))).round(2)*100).to_i #/ This is for jEdit syntax highlighting to fix
                      end
                    end
                  end
                  if @parser_status == :retnormal
                    #puts "DEBUG: Parser returning to normal mode"
                    @parser_status = :normal
                  end
                elsif @conversion_type == :video
                  if @parser_status == :meta
                    #puts "DEBUG: Parser in metadata parsing mode"
                    if line[0..7] == "Duration" || line[0..5] == "Stream" || line[0] == "[" || line[0..5] == "Output" || line[0..4] == "Input" 
                      @parser_status = :normal
                    else
                      #puts "DEBUG: Reading metadata line..."
                      if @last_met_io == :input
                        if @last_stream_type == nil
                          @input_meta_common[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                        elsif @last_stream_type == :audio
                          @input_meta_audio[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                        elsif @last_stream_type == :video
                          @input_meta_video[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                        end
                      elsif @last_met_io == :output
                        if @last_stream_type == nil
                          @output_meta_common[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                        elsif @last_stream_type == :audio
                          @output_meta_audio[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                        elsif @last_stream_type == :video
                          @output_meta_video[line.split(":")[0].downcase[0..-2].to_sym] = line.split(":")[1][1..-1]
                        end
                      end
                    end
                  end
                 if @parser_status == :strmap
                    #puts "DEBUG: Parser in stream mapping parsing mode"
                    #puts "DEBUG: Reading stream mapping information..."
                    @stream_mapping_video = line[21..-2]
                    @parser_status = :strmap2
                  elsif @parser_status == :strmap2
                    @stream_mapping_audio = line[21..-2]
                    @parser_status = :retnormal
                  end
                  if @parser_status == :normal
                    #puts "DEBUG: Parser in normal mode"
                    if line[0..5] == "ffmpeg"
                      #puts "DEBUG: Approached version line"
                      @ff_versionline = line
                    elsif line[0..4] == "built"
                      #puts "DEBUG: Approached build line"
                      @ff_buildline = line
                    elsif line[0..4] == "Input"
                      #puts "DEBUG: Approached input declaration"
                      @input_type = line.split(",")[1][1..-1]
                      @last_met_io = :input
                      @last_stream_type = nil
                    elsif line[0..5] == "Output"
                      #puts "DEBUG: Approached output declaration"
                      @detected_output_type = line.split(",")[1][1..-1]
                      @last_met_io = :output
                      @last_stream_type = nil
                    elsif line == "Metadata:"
                      #puts "DEBUG: Approached metadata start"
                      @parser_status = :meta
                    elsif line[0..7] == "Duration"
                      #puts "DEBUG: Approached duration line"
                      @input_duration = line.split(",")[0][10..-1]
                      if line.split(",")[1][1..5] == "start"
                        #puts "DEBUG: Detected start variation of the line"
                        @input_start = line.split(",")[1][8..-1]
                        @input_bitrate = line.split(",")[2][10..-1]
                      else
                        #puts "DEBUG: Detected only bitrate variation of the line"
                        @input_bitrate = line.split(",")[1][10..-1]
                      end
                    elsif line == "Stream mapping:"
                      #puts "DEBUG: Approached stream mapping declaration"
                      @parser_status = :strmap
                    elsif line[0..5] == "Stream"
                      #puts "DEBUG: Approached stream information line"
                      if line[13..17] == "Video"
                        @last_stream_type = :video
                      elsif line[13..17] == "Audio"
                        @last_stream_type = :audio
                      else
                        @last_stream_type = nil
                      end
                      if @last_met_io == :input
                        if @last_stream_type == :video
                          @video_input_format = line.split(",")[0][20..-1]
                          @video_input_colorspace = line.split(",")[1][1..-1]
                          @video_input_resolution = line.split(",")[2][1..-1]
                          @video_input_additional = line.split(",")[3..-1]
                        elsif @last_stream_type == :audio
                          @audio_input_format = line.split(",")[0][20..-1]
                          @audio_input_freq = line.split(",")[1][1..-1]
                          @audio_input_channelmode = line.split(",")[2][1..-1]
                          @audio_input_format_type = line.split(",")[3][1..-1]
                          if line.split(",")[4] != nil
                            @audio_input_bitrate2 = line.split(",")[4][1..-1]
                          end
                        end
                      elsif @last_met_io == :output
                        if @last_stream_type == :video
                          @video_output_format = line.split(",")[0][20..-1]
                          @video_output_colorspace = line.split(",")[1][1..-1]
                          @video_output_resolution = line.split(",")[2][1..-1]
                          @video_output_additional = line.split(",")[3..-1]
                        elsif @last_stream_type == :audio
                          @audio_output_format = line.split(",")[0][20..-1]
                          @audio_output_freq = line.split(",")[1][1..-1]
                          @audio_output_channelmode = line.split(",")[2][1..-1]
                          @audio_output_format_type = line.split(",")[3][1..-1]
                          if line.split(",")[4] != nil
                            @audio_output_bitrate2 = line.split(",")[4][1..-1]
                          end
                        end
                      end
                    elsif line[0..4] == "frame"
                      #puts "DEBUG: Approached processing status line"
                      line.split(" ").each do |spl|
                        @processing_status[spl.split("=")[0].to_sym] = spl.split("=")[1]
                      end
                      if @processing_status[:time] != nil && @input_duration != nil
                        @processing_percentage = ((((Time.parse(@processing_status[:time])-Time.parse("0:0"))/(Time.parse(@input_duration)-Time.parse("0:0")))).round(2)*100).to_i #/ This is for jEdit syntax highlighting to fix
                      end
                    end
                  end
                  if @parser_status == :retnormal
                    #puts "DEBUG: Parser returning to normal mode"
                    @parser_status = :normal
                  end
                end
              end
            end while line != "EOF"
            #puts "DEBUG: After EOF, closing streams..."
            progout.close
            progin.close
            progthread.join
            progst = progthread.value
            @exit_status = progst.exitstatus
            #puts "Got output status: #{progst.exitstatus}"
            if progst.success?
              @status = :completed
              @processing_percentage = 100
            else
              @status = :failed
            end
          end
          if @status == :failed
            raise RFF::ProcessingFailure.new(@exit_status, "Inspect the output as FFmpeg returned with status: ")
          end
        rescue => e
          puts "Caught exception: " + e.to_s
          puts "Backtrace:"
          puts e.backtrace
          @status = :failed
        end
      end
    end
    
    # This method returns full input path
    
    def input
      @input
    end
    
    # This method returns output type read from the filename
    
    def output_type
      @output_type
    end
    
    # This method returns output type read by FFmpeg
    
    def detected_output_type
      @detected_output_type
    end
    
    # This method returns full output name
    
    def output_name
      @output_name
    end
    
    # This method returns path where the output is (being) saved
    
    def output_path
      @output_path
    end
    
    # This method returns used video quality
    
    def quality
      @quality
    end
    
    # This method returns the FFmpeg command used for conversion
    
    def command
      @command
    end
    
    # This method returns custom arguments passed to FFmpeg
    
    def custom_args
      @custom_args
    end
    
    # This method returns conversion type (:audio or :video)
    
    def conversion_type
      @conversion_type
    end
    
    # This method returns full path to the output file
    
    def full_output_path
      "#{@output_path}/#{@output_name}.#{@output_type.to_s}"
    end
      
    # This method returns raw command output as an array of lines after getting rid of unneeded whitespaces
    
    def raw_command_output
      @rawoutput
    end
    
    # This method returns current processing status (:pending, :processing, :completed, :failed, :aborted)
    
    def status
      @status
    end
    
    # This method returns current output parser status
    
    def parser_status
      @parser_status
    end
    
    # This method returns common metadata for input streams as a hash with keys being symbols representing each metadata downcased name
    
    def common_input_metadata
      @input_meta_common
    end
    
    # This method returns metadata for audio input stream as a hash with keys being symbols representing each metadata downcased name
    
    def audio_input_metadata
      @input_meta_audio
    end
    
    # This method returns metadata for video input stream as a hash with keys being symbols representing each metadata downcased name
    
    def video_input_metadata
      @input_meta_video
    end
    
     # This method returns common metadata for output streams as a hash with keys being symbols representing each metadata downcased name
    
    def common_output_metadata
      @output_meta_common
    end
    
    # This method returns metadata for audio output stream as a hash with keys being symbols representing each metadata downcased name
    
    def audio_output_metadata
      @output_meta_audio
    end
    
    # This method returns metadata for video output stream as a hash with keys being symbols representing each metadata downcased name
    
    def video_output_metadata
      @output_meta_video
    end
    
    # This method returns a hash which represents current processing status (eg. frames processed, time processed etc.) with keys being symbols representing each status value
    
    def processing_status
      @processing_status
    end
    
    # This method returns audio stream mapping information (input_format -> output_format)
    
    def audio_stream_mapping
      @stream_mapping_audio
    end
    
    # This method returns video stream mapping information (input_format -> output_format)
    
    def video_stream_mapping
      @stream_mapping_video
    end
    
    # This method returns FFmpeg version line
    
    def ffmpeg_version_line
      @ff_versionline
    end
    
    # This method returns FFmpeg build line
    
    def ffmpeg_build_line
      @ff_buildline
    end
    
    # This method returns input type detected by FFmpeg
    
    def input_type
      @input_type
    end
    
    # This method returns input duration
    
    def input_duration
      @input_duration
    end
    
    # This method returns start point of the input
    
    def input_start
      @input_start
    end
    
    # This method returns input bitrate (from the duration line)
    
    def input_bitrate
      @input_bitrate
    end
    
    # This method returns format of audio input
    
    def audio_input_format
      @audio_input_format
    end
    
    # This method returns frequency of audio input
    
    def audio_input_frequency
      @audio_input_freq
    end
    
    # This method returns channel mode (eg. mono, stereo) of audio input
    
    def audio_input_channelmode
      @audio_input_channelmode
    end
    
    # This method returns type of format of audio input
    
    def audio_input_format_type
      @audio_input_format_type
    end
    
    # This method returns bitrate of audio input (from input information line)
    
    def audio_input_bitrate2
      @audio_input_bitrate2
    end
    
    # This method returns format of audio output
    
    def audio_output_format
      @audio_output_format
    end
    
    # This method returns frequency of audio output
    
    def audio_output_frequency
      @audio_output_freq
    end
    
    # This method returns channel mode (eg. mono, stereo) of audio output
    
    def audio_output_channelmode
      @audio_output_channelmode
    end
    
    # This method returns type of format of audio output
    
    def audio_output_format_type
      @audio_output_format_type
    end
    
    # This method returns bitrate of audio output (from output information line)
    
    def audio_output_bitrate2
      @audio_output_bitrate2
    end
    
    # This method returns format of video input
    
    def video_input_format
      @video_input_format
    end
    
    # This method returns color space of video input
    
    def video_input_colorspace
      @video_input_colorspace
    end
    
    # This method returns resolution of video input
    
    def video_input_resolution
      @video_input_resolution
    end
    
    # This method returns additional information about video input as an array of values
    
    def video_input_additional
      @video_input_additional
    end
    
    # This method returns format of video output
    
    def video_output_format
      @video_output_format
    end
    
    # This method returns color space of video output
    
    def video_output_colorspace
      @video_output_colorspace
    end
    
    # This method returns resolution of video output
    
    def video_output_resolution
      @video_output_resolution
    end
    
    # This method returns additional information about video output as an array of values
    
    def video_output_additional
      @video_output_additional
    end
    
    # This method returns percentage of process completion
    
    def processing_percentage
      @processing_percentage || 0
    end
    
    # This method returns percentage of process completion formatted for output
    
    def format_processing_percentage
      @processing_percentage.nil? ? "0%" : @processing_percentage.to_s + "%"
    end
    
    # This method returns the exit status of the FFmpeg command
    
    def command_exit_status
      @exit_status
    end
    
    # This method kills processing thread and sets status to :aborted
    
    def kill
      @processing_thread.kill
      @status = :aborted
    end
  end
end
