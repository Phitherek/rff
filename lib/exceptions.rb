module RFF
  
  # This exception is thrown on insufficient arguments to the method
  
  class ArgumentError < ::ArgumentError
  end
  
  # This exception is thrown on FFmpeg processing error
  
  class ProcessingFailure < ::RuntimeError
    
    # Initializes the exception with arguments
    # * _exitcode_ <b>(required)</b> - FFmpeg exit code
    # * _msg_ - Message describing the error. Defaults to nil
    
    def initialize(exitcode, msg=nil)
      @msg = msg
      @exitcode = exitcode
    end
    
    # Returns message describing the error (exit code and describing message if it is present)
    
    def to_s
      if msg.nil?
        exitcode.to_s
      else
        msg + exitcode.to_s
      end
    end
  end
end
