# -*- coding: utf-8 -*-
# Copyright (C) 2010, 2011 Rocky Bernstein <rockyb@rubyforge.net>
# A base class for debugger subcommands of subcommands.
#
# Note: don't end classname with Command (capital C as in SubCommand),
# since main will think this a command name like QuitCommand 
#                                                    ^   

# Base Class for Trepan subcommands. We pull in some helper
# functions for command from module cmdfns.

require_relative '../../command'
require_relative 'subcmd'

class Trepan

  class SubSubcommand  < Subcommand
    def initialize(cmd, parent, name)
      @cmd    = cmd
      @name   = name
      @parent = parent
      @proc   = parent.proc
    end

    def settings
      @parent.settings
    end

    def string_in_show
      help_constant_sym = if self.class.constants.member?(:SHORT_HELP) 
                            :SHORT_HELP 
                          else :HELP
                          end
      str = my_const(help_constant_sym)
      %w(Show Set).each do |word|
        if 0 == str.index(word)
          str = str[word.size+1 ..-1].capitalize
          break
        end
      end
      str
    end

    # Set a Boolean-valued debugger setting. 
    def run_set_bool(args, default=true)
      set_val = args.size < 2 ? 'on' : args[1]
      setting = @name.gsub(/^(set|show)/,'')
      begin
        settings[setting.to_sym] = @proc.get_onoff(set_val)
        run_show_bool(string_in_show)
      rescue NameError, TypeError
      end
    end

    def run_show_bool(what=nil)
      setting = @name.gsub(/^(set|show)/,'')
      val = show_onoff(settings[setting.to_sym])
      what = setting unless what
      msg('%s is %s.' % [what.chomp, val])
    end

  end

  class SetBoolSubSubcommand < SubSubcommand
    completion %w(on off)
    def run(args)
      run_set_bool(args)
    end

    def save_command
      val     = settings[subcmd_setting_key] ? 'on' : 'off'
      ["#{subcmd_prefix_string} #{val}"]
    end
  end

  class ShowBoolSubSubcommand < SubSubcommand
    def run(args)
      run_show_bool(string_in_show)
    end
  end

  class ShowIntSubSubcommand < SubSubcommand
    def run(args)
      run_show_int
    end
  end
end

module Trepanning
  module SubSubcommand
    module_function
    def set_name_prefix(__file__, klass)
      full_dirname = File.dirname(File.expand_path(__file__))
      full_parent_dirname = File.expand_path(File.join(full_dirname, '..'))
      dirname = File.basename(full_dirname)
      parent_dirname = File.basename(full_parent_dirname)
      name = File.basename(__file__, '.rb')
      klass.const_set('NAME', name)

      short_dirname = dirname[0...-'_subcmd'.size]
      short_parent_dirname = parent_dirname[0...-'_subcmd'.size]
      prefix = klass.const_set(:PREFIX, %W(#{short_parent_dirname} 
                                            #{short_dirname} #{name}))
      klass.const_set(:CMD, prefix.join(' '))
    end
  end
end


if __FILE__ == $0
  # Demo it.
  require_relative '../../mock'
  require_relative '../../subcmd'
  name = File.basename(__FILE__, '.rb')

  # FIXME: DRY the below code
  dbgr, info_cmd = MockDebugger::setup('info')
  testcmdMgr = Trepan::Subcmd.new(info_cmd)
  cmd_name   = 'testing'
  infox_cmd  = Trepan::SubSubcommand.new(info_cmd.proc,
                                         info_cmd,
                                         cmd_name)
  infox_cmd.settings
end
