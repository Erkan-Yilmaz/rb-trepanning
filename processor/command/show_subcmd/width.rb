# -*- coding: utf-8 -*-
require_relative File.join(%w(.. base_subcmd))

class Debugger::Subcommand::ShowWidth < Debugger::ShowIntSubcommand
  unless defined?(HELP)
    HELP = 'Show the number of characters the debugger thinks are in a line'
    MIN_ABBREV   = 'wid'.size
    NAME         = File.basename(__FILE__, '.rb')
    SHORT_HELP   = HELP
  end

end

if __FILE__ == $0
  # Demo it.
  require_relative File.join(%w(.. .. mock))
  require_relative File.join(%w(.. .. subcmd))
  dbgr = MockDebugger.new
  cmds = dbgr.core.processor.instance_variable_get('@commands')
  cmd = cmds['exit']
  subcommand = Debugger::Subcommand::ShowWidth.new(cmd)
  testcmdMgr = Debugger::Subcmd.new(subcommand)

  def subcommand.msg(message)
    puts message
  end
  def subcommand.msg_nocr(message)
    print message
  end
  def subcommand.errmsg(message)
    puts message
  end
  subcommand.run_show_int
  name = File.basename(__FILE__, '.rb')
  subcommand.summary_help(name)
end