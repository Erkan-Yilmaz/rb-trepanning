require 'thread_frame'
require_relative File.join(%w(.. processor main))
class Debugger
  # This class contains the Debugger core routines, such as an event
  # processor is responsible of handling what to do when an event is
  # triggered.
  # 
  # See also 'rdbgr' the top-level Debugger class and command-line routine
  # which ultimately will call this.

  class Core
    attr_reader   :dbgr       # Debugger instance
    attr_reader   :event      # String - event which triggering event
                              # processor
    attr_reader   :frame      # ThreadFrame instance
    attr_accessor :processor  # Debugger::CmdProc instance
    attr_reader   :settings   # Hash of things you can configure

    DEFAULT_SETTINGS = {
      :cmdproc_opts => {}
    } unless defined?(DEFAULT_SETTINGS)

    def initialize(debugger, settings={})
      @dbgr      = debugger
      @settings  = DEFAULT_SETTINGS.merge(settings)
      @processor = CmdProcessor.new(self, @settings[:cmdproc_opts])
    end

    # A trace-hook processor with the interface a trace hook should have.
    def event_processor(event, frame, arg=nil)
      # FIXME: Block all other threads
      @arg   = arg
      @event = event
      @frame = frame
      while @frame.type == 'IFUNC'
        @frame = @frame.prev
      end
      @processor.process_commands(@frame)

      # FIXME: unblock other threads
    end

    # A Ruby 1.8-style event processor. We don't use file, line, id, bind. 
    def old_event_processor(event, file, line, id, bind, klass)
      event_processor(event, RubyVM::ThreadFrame.current.prev)
    end

    # Call this from inside the program you want to get a synchronous
    # call to the debugger.
    def debugger
      frame = RubyVM::ThreadFrame.current.prev
      event_processor('debugger-call', frame)
    end
    
  end
end
if __FILE__ == $0
  require_relative File.join(%w(.. rbdbgr))
  dbg = Debugger.new()
  if ARGV.size > 0
    def foo(dbg)
      p 'foo here'
      dbg.debugger
    end
    foo(dbg)
  end
end
