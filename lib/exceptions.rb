module RFF
  class ArgumentError < ::ArgumentError
  end
  
  class ProcessingFailure < ::RuntimeError
    def initialize(exitcode, msg=nil)
      @msg = msg
      @exitcode = exitcode
    end
    def to_s
      if msg.nil?
        exitcode.to_s
      else
        msg + exitcode.to_s
      end
    end
  end
end
