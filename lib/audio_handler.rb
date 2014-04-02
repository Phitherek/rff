require_relative 'processor'

module RFF
  class AudioHandler
    def initialize input, output_path=nil, quality="5000k", custom_args=nil, recommended_audio_quality=true
      @input = input
      @input_type = File.basename(@input).split(".")[1]
      @output_path = output_path
      @quality = quality
      @custom_args = custom_args
      @processing_percentage = 0
      @processors = []
      types = [:mp3, :ogg, :wav]
      if types.include?(@input_type.to_sym)
        types.delete(@input_type.to_sym)
      end
      types.each do |type|
        @processors << RFF::Processor.new(@input, type, @output_path, @quality, @custom_args, recommended_audio_quality)
      end
    end
    
    def fire_all
      @processing_thread = Thread.new do |th|
        begin
          @processors.each do |proc|
            proc.fire
            sleep(5)
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
            sleep(5)
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
    
    def killall
      @processors.each do |proc|
        proc.kill
      end
      @processing_thread.kill
    end
    
    def mp3_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :mp3
          ret = proc
        end
      end
      ret
    end
    
    def ogg_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :ogg
          ret = proc
        end
      end
      ret
    end
    
    def wav_processor
      ret = nil
      @processors.each do |proc|
        if proc.output_type == :wav
          ret = proc
        end
      end
      ret
    end
    
    def input
      @input
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
    
    def custom_args
      @custom_args
    end
    
    def processing_percentage
      @processing_percentage || 0
    end
    
    def format_processing_percentage
      @processing_percentage.nil? ? "0%" : @processing_percentage.to_s + "%"
    end
  end
end
