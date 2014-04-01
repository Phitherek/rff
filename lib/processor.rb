require_relative 'exceptions'
require_relative 'output_reader'
require 'open3'
require 'time'
module RFF
  class Processor
    def initialize input, output_type, output_path=nil, quality="5000k", custom_args=nil
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
        @command = "ffmpeg -y -i #{@input} -acodec #{@output_type == :mp3 ? "libmp3lame" : (@output_type == :ogg ? "libvorbis" : "pcm_s16le")}#{@custom_args.nil? ? "" : " #{@custom_args}"} #{@output_path}/#{@output_name}.#{@output_type.to_s}"
        @conversion_type = :audio
      else
        @command = "ffmpeg -y -i #{@input} -acodec #{(@output_type == :webm || @output_type == :ogv) ? "libvorbis" : "aac"} -vcodec #{@output_type == :webm ? "libvpx" : (@output_type == :ogv ? "libtheora" : "mpeg4")}#{@output_type == :mp4 ? " -strict -2" : ""}#{(!@quality.nil? && !@quality.empty?) ? " -b:v #{@quality}" : ""}#{@custom_args.nil? ? "" : " #{@custom_args}"} #{@output_path}/#{@output_name}.#{@output_type.to_s}"
        @conversion_type = :video
      end
      @status = :pending
    end
    
    def fire
      @processing_thread = Thread.new do |th|
        begin
          Open3.popen2e(@command) do |progin, progout, progthread|
            @status = :processing
            @parser_status = :normal
            outputreader = OutputReader.new(progout)
            @rawoutput = []
            @input_meta_audio = {}
            @input_meta_video = {}
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
                #puts "DEBUG: Parsing line..."
                if @conversion_type == :audio
                  if @parser_status == :meta
                    #puts "DEBUG: Parser in metadata parsing mode"
                    if line[0..7] == "Duration" || line[0..5] == "Stream"
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
                    #uts "DEBUG: Parser in stream mapping parsing mode"
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
                      @output_type = line.split(",")[1][1..-1]
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
                        @input_format = line.split(",")[0][20..-1]
                        @input_freq = line.split(",")[1][1..-1]
                        @input_channelmode = line.split(",")[2][1..-1]
                        @input_format_type = line.split(",")[3][1..-1]
                        if line.split(",")[4] != nil
                          @input_bitrate2 = line.split(",")[4][1..-1]
                        end
                      elsif @last_met_io == :output
                        @output_format = line.split(",")[0][20..-1]
                        @output_freq = line.split(",")[1][1..-1]
                        @output_channelmode = line.split(",")[2][1..-1]
                        @output_format_type = line.split(",")[3][1..-1]
                        if line.split(",")[4] != nil
                          @output_bitrate2 = line.split(",")[4][1..-1]
                        end
                      end
                    elsif line[0..3] == "size"
                      #puts "DEBUG: Approached processing status line"
                      line.split(" ").each do |spl|
                        @processing_status[spl.split("=")[0].to_sym] = spl.split("=")[1]
                      end
                      @processing_percentage = ((((Time.parse(@processing_status[:time])-Time.parse("0:0"))/(Time.parse(@input_duration)-Time.parse("0:0")))).round(2)*100).to_i #/ This is for jEdit syntax highlighting to fix
                    end
                  end
                  if @parser_status == :retnormal
                    #puts "DEBUG: Parser returning to normal mode"
                    @parser_status = :normal
                  end
                elsif @conversion_type == :video
                  puts "Not implemented yet... Just wait for the conversion to stop."
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
        end
      end
    end
    
    def input
      @input
    end
    
    def output_type
      @output_type
    end
    
    def output_name
      @output_name
    end
    
    def output_path
      @output_path
    end
    
    def quality
      @quality
    end
    
    def command
      @command
    end
    
    def custom_args
      @custom_args
    end
    
    def conversion_type
      @conversion_type
    end
    
    def full_output_path
      "#{@output_path}/#{@output_name}.#{@output_type.to_s}"
    end
      
    def raw_command_output
      @rawoutput
    end
    
    def status
      @status
    end
    
    def parser_status
      @parser_status
    end
    
    def audio_input_metadata
      @input_meta_audio
    end
    
    def video_input_metadata
      @input_meta_video
    end
    
    def audio_output_metadata
      @output_meta_audio
    end
    
    def video_output_metadata
      @output_meta_video
    end
    
    def processing_status
      @processing_status
    end
    
    def audio_stream_mapping
      @stream_mapping_audio
    end
    
    def ffmpeg_version_line
      @ff_versionline
    end
    
    def ffmpeg_build_line
      @ff_buildline
    end
    
    def input_type
      @input_type
    end
    
    def output_type
      @output_type
    end
    
    def input_duration
      @input_duration
    end
    
    def input_start
      @input_start
    end
    
    def input_bitrate
      @input_bitrate
    end
    
    def input_format
      @input_format
    end
    
    def input_frequency
      @input_freq
    end
    
    def input_channelmode
      @input_channelmode
    end
    
    def input_format_type
      @input_format_type
    end
    
    def input_bitrate2
      @input_bitrate2
    end
    
    def output_format
      @output_format
    end
    
    def output_frequency
      @output_freq
    end
    
    def output_channelmode
      @output_channelmode
    end
    
    def output_format_type
      @output_format_type
    end
    
    def output_bitrate2
      @output_bitrate2
    end
    
    def processing_percentage
      @processing_percentage
    end
    
    def format_processing_percentage
      @processing_percentage.to_s + "%"
    end
    
    def command_exit_status
      @exit_status
    end
  end
end