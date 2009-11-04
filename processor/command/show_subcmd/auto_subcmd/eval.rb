# -*- coding: utf-8 -*-
require_relative %w(.. .. base subsubcmd)

class Debugger::SubSubcommand::ShowAutoEval < Debugger::ShowBoolSubSubcommand
  unless defined?(HELP)
    HELP = "Show evaluation of unrecognized debugger commands"
    MIN_ABBREV   = 'ev'.size
    NAME         = File.basename(__FILE__, '.rb')
    PREFIX       = %w(show auto eval)
  end

end

if __FILE__ == $0
  # Demo it.
  require_relative %w(.. .. .. mock)
  require_relative %w(.. .. .. subcmd)
  name = File.basename(__FILE__, '.rb')

  # FIXME: DRY the below code
  dbgr, show_cmd = MockDebugger::setup('show')
  testcmdMgr     = Debugger::Subcmd.new(show_cmd)
  auto_cmd       = Debugger::SubSubcommand::ShowAuto.new(dbgr.core.processor, 
                                                         show_cmd)

  # FIXME: remove the 'join' below
  cmd_name       = Debugger::SubSubcommand::ShowAutoEval::PREFIX.join('')
  autox_cmd      = Debugger::SubSubcommand::ShowAutoEval.new(show_cmd.proc, auto_cmd,
                                                             cmd_name)
  # require_relative %w(.. .. .. .. rbdbgr)
  # dbgr = Debugger.new(:set_restart => true)
  # dbgr.debugger
  autox_cmd.run([])

end