# -*- coding: utf-8 -*-
# Interface when communicating with the user in the same process as
# the debugged program.

## import atexit -- from python

# Our local modules

require_relative 'base_intf'

# Minput     = import_relative('dbg_input', '..io', 'pydbgr')
# Moutput    = import_relative('dbg_output', '..io', 'pydbgr')

# Interface when communicating with the user in the same
# process as the debugged program.
class Debugger::UserInterface < Debugger::Interface

  FILE_HISTORY = '.rbdbgr_hist' unless defined?(FILE_HISTORY)

  def initialize(inp=nil, out=nil, opts={})
    # atexit.register(self.finalize)
    super(inp, out, opts)
    begin
      require 'readline'
      @have_gnu_readline = true
    rescue LoadError
      @have_gnu_readline = false
    end
    @use_gnu_readline = @have_gnu_readline
    @interactive = true # Or at least so we think initially
  end

  # Closes both input and output
  def close
    @input.close
    @output.close
  end

  # Called when a dangerous action is about to be done, to make
  # sure it's okay. Expect a yes/no answer to `prompt' which is printed,
  # suffixed with a question mark and the default value.  The user
  # response converted to a boolean is returned.
  def confirm(prompt, default)
    default_str = default ? 'Y/n' : 'N/y'
    while true do
      response = readline('%s (%s) ' % 
                          [prompt, default_str])
      response = if response 
                   response.strip.downcase
                 else
                   default
                 end
      if response.empty?
        response = default
        break
      end
      # We don't catch "Yes, I'm sure" or "NO!", but I leave that 
      # as an excercise for the reader.
      break if YES_OR_NO.member?(response)
      msg "Please answer 'yes' or 'no'. Try again."
    end
    return YES.member?(response)
  end

  # Common routine for reporting debugger error messages.
  def errmsg(msg, prefix='*** ')
    return msg("%s%s" % [prefix, msg])
  end

  def finalize(last_wishes=none)
    # print exit annotation
    # save history
    super
  end

  def read_command(prompt='')
    line = self.readline(prompt)
    # FIXME: Do something with history?
    return line
  end

  def readline(prompt='')
    @output.flush()
    if @use_gnu_readline
      return Readline.readline(prompt)
      unless line
        @eof = true
        raise EOFError
      end
    else
      if prompt and prompt.size > 0
        @output.print(prompt)
      end
      begin
        return @input.readline()
      rescue EOFError
        @eof = true
        raise
      end
    end
  end
end

# Demo
if __FILE__ == $0
  intf = Debugger::UserInterface.new
  intf.errmsg("Houston, we have a problem here!")
  if ARGV.size > 0
    begin
      line = intf.readline("Type something: ")
    rescue EOFError
      puts "No input, got EOF"
    else
      puts "You typed: #{line}"
    end
    puts "EOF is now: %s" % intf.eof?.inspect
    unless intf.eof?
      line = intf.confirm("Are you sure", false)
      puts "You typed: #{line}"
      line = intf.confirm("Are you not sure", true)
      puts "You typed: #{line}"
    end
  end
end
