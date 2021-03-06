#!/usr/bin/env ruby
require 'test/unit'
require_relative 'helper'

class TestDebuggerStop < Test::Unit::TestCase
  @@NAME = File.basename(__FILE__, '.rb')[5..-1]

  def test_it
    opts = {}
    opts[:feed_input] = "echo 'info program ;; continue ;; quit!' "
    opts[:filter] = Proc.new{|got_lines, correct_lines|
      got_lines[0].gsub!(/\(.*debugger-stop.rb[:]\d+ @\d+/, 
                         'debugger-stop.rb:14 @1955')
      # require_relative '../../lib/trepanning'; debugger
      got_lines[2].gsub!(/PC offset \d+ .*<top .+debugger-stop.rb/, 
                         "PC offset 100 <top debugger-stop.rb")
      got_lines[3].gsub!(/\(.*debugger-stop.rb[:]\d+ @\d+/, 
                         'debugger-stop.rb:10 @1954')
    }
    assert_equal(true, run_debugger(@@NAME, @@NAME + '.rb', opts))
  end
end
