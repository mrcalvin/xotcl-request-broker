::xo::library doc {
  
  An adaptation of the scenario-based testing framework (STORM),
  orginally developed by Mark Strembeck (c), for the use within xorb 
  and its protocol plug-ins.
  This adaptation is based upon v0.4 of the original code.
  For the conceptual background, see
  http://wi.wu-wien.ac.at/home/mark/publications/tecos04.pdf
  
  @author mark.strembeck@wu-wien.ac.at
  @author stefan.sobernig@wu-wien.ac.at
  @creation-date September 10, 2007
  @cvs-id $Id$

}

namespace eval ::xorb::storm {

  Class Timestamp
  Timestamp instproc init {} {
    my set itime [clock clicks -milliseconds]
  }
  Timestamp instproc diff {} {
    my instvar itime
    set now [clock clicks -milliseconds]
    return [expr {$now-$itime}]
  }

  # / / / / / / / / / / / / / / / /
  # Class Test
  # - - - - - - - - - - - - - - - - 

  ::xotcl::Class Test -slots {
    Attribute scope
    Attribute description -default ""
    Attribute node
  }
  #Test abstract instproc run {}
  Test instproc init args {
    next
  }
  Test instproc run args {
    next
  }
  Test instproc resolve {what} {
    if {[my exists $what]} {
      return [my set $what]
    } elseif {[my exists __parent] && [my set __parent] ne {}} {
      return [[my set __parent] resolve $what]
    } else {
      error "'$what' cannot be resolve in a Chain of Responsibility."
    }
  }
  Test instproc getNode {name} {
    set pn [my resolve node]
    set doc [$pn ownerDocument]
    set n [$doc createElement $name]
    $pn appendChild $n
    return $n
  }
  Test instproc getScope {} {
    return [my resolve scope]
  }
  Test instproc mockEval script {
    set scope [my getScope]
    #ns_write SCOPE=$scope\n
    if {![namespace exists $scope]} {
      $scope requireNamespace
    }
    namespace eval $scope $script
  }
  Test instproc unsatisfied {result} {
    $result reference [self]
    my report $result
    error $result
  }
  Test instproc satisfied {result} {
    $result reference [self]
    my report $result
  }
  Test instproc report {{-stop:switch false} result} {
    if {!$stop} {
      if {[my exists __parent] && [my set __parent] ne {}} {
	[my set __parent] report -stop $result
      }
    }
  }
  Test instproc finalise {} {
    my instvar node attributes timestamp
    if {[my exists timestamp]} {
      my set attributes(grosstime) [$timestamp diff]
    }
    foreach {attr val} [array get attributes] {
      catch {set val [subst $val]}
      if {$val ne {}} {
	$node setAttribute $attr $val
      }
    }
    next
  }

  # / / / / / / / / / / / / / / / /
  # Class Guardian
  # - - - - - - - - - - - - - - - - 
  # A  guardian evaluates pre- and
  # post-conditions upon execution
  # of a test item.
  
  ::xotcl::Class Guardian -slots {
    Attribute preconditions -default "" -multivalued true
    Attribute postconditions -default "" -multivalued true
  }
  Guardian instproc run {} {
    my checkPreConditions
    if {![catch {next} result]} {
      my checkPostConditions
    } else {
      error $result
    }
  }
  Guardian instproc checkPreConditions {} {
    my instvar preconditions
    #ns_write "[self]: preconds\n"
    foreach pre $preconditions {
      if {![my mockEval $pre]} {
	my unsatisfied [ConditionUnsatisfied new $pre]
      }
    }
  }
  Guardian instproc checkPostConditions {} {
    my instvar postconditions
    #ns_write "[self]: postconds\n"
    foreach post $postconditions {
      if {![my mockEval $post]} {
	my unsatisfied [ConditionUnsatisfied new $post]
      }
    }
  }
  Guardian instproc report {{-stop:switch false} result} {
    if {[$result istype ConditionUnsatisfied] && [$result = [self]]} {
      my instvar node
      # / / / / / / / / / / / / / / / / / / / /
      # !!!! report could be called before
      # run and, therefore, the init of 
      # an element node. We lazily acquire one
      # in that case.
      if {![info exists node]} {
	set node [my getNode]
	my array set attributes [array get defaults]
      }
      set doc [$node ownerDocument]
      set n [$doc createElement system-err]
      $node appendChild $n
      $n setAttribute type [namespace tail [$result info class]]
      set t [$doc createTextNode [$result message]]
      $n appendChild $t
    } 
    next
  }
  

  # / / / / / / / / / / / / / / / /
  # Class Fixture
  # - - - - - - - - - - - - - - - - 
  # A fixture, as known from xUnit
  # frameworks, represents a testbed
  # for dependent, aggregated test entities,
  # in STORM established by setup_script
  # and cleanup_script

  ::xotcl::Class Fixture -slots {
    Attribute setup_script
    Attribute cleanup_script
    Attribute halt_on_first_error -default 0 
  } -superclass {
    Test 
    ::xo::OrderedComposite
  }
  Fixture instproc run {} {
    my instvar setup_script cleanup_script \
	halt_on_first_error
    set ts [Timestamp new -volatile]
    if {[info exists setup_script]} {
      #ns_write "[self]: setup_script\n"
      if {[catch {my mockEval $setup_script} msg]} {
	my unsatisfied [PrerequisiteUnsatisfied new $msg]
      }
    }
    foreach c [my children] {
      #set tsc [Timestamp new -volatile]
      if {[catch {$c run} result]} {
	#ns_write "[self]: UNSATISFIED(Fixture), $result\n"
	my unsatisfied $result
      }
      #$c set attributes(grosstime) [$tsc diff]
    }
    next
    if {[info exists cleanup_script]} {
      #ns_write "[self]: cleanup_script\n"
      if {[catch {my mockEval $cleanup_script} msg]} {
	my unsatisfied [PrerequisiteUnsatisfied new $msg]
      }
    }
    if {[my exists non_halting_error]} {
      my finalise
      error [Unsatisfied new "failed"]
    }
  }
  Fixture instproc unsatisfied result {
    my instvar halt_on_first_error
    # report
    if {![$result exists reference] || [$result reference] eq {}} {
      $result reference [self]
    }
    my report $result
    if {$halt_on_first_error} {
      #ns_write HALT_ON_FIRST_ERROR\n
      my finalise
      error $result
    } else {
      my set non_halting_error 1
    }
  }
  Fixture instproc report {{-stop:switch false} result} {
    if {[$result istype PrerequisiteUnsatisfied] && [$result = [self]]} {
      #ns_write PREREQError\n
      my instvar node
      set doc [$node ownerDocument]
      set n [$doc createElement system-err]
      $node appendChild $n
      $n setAttribute type [namespace tail [$result info class]]
      set t [$doc createTextNode [$result message]]
      $n appendChild $t
    } 
    next
  }
  
  # / / / / / / / / / / / / / /
  # Class TestSuite

  Class TestSuite \
      -superclass Fixture \
      -array set defaults {
	cases 		0
	unsatisfied	0
      }
  TestSuite instproc init args {
    my instvar scope node
    set scope [self]
    next
  }
  TestSuite instproc run {} {
    my instvar node
    my set timestamp [Timestamp new -destroy_on_cleanup]
    if {![info exists node]} {
      [self class] instvar defaults
      # / / / / / / / / / / /
      # prepare XML reporting
      set document [dom createDocument testsuite]
      set node [$document documentElement]
      $node setAttribute name [namespace tail [self]]
      my array set attributes [array get defaults]
    }
    #ns_write "[self]: RUN\n"
    if {[catch {next} result]} {
      #ns_write "[self]: FAILED and HALTED: $result"
    } 
    my finalise
  }
  TestSuite instproc report {{-stop:switch false} result} {
    my instvar node
    if {$stop} {
      # / / / / / / / / / / / / /
      # aggregates goes here!
      my incr attributes(cases)
      if {[$result istype Unsatisfied]} {
	my incr attributes(unsatisfied)
      }
    }
    #ns_write "[self] REPORT args=[$result serialize],stop=$stop\n"
    next;# Test->report
  }
  TestSuite instproc getReport {} {
    my instvar node
    return [$node asXML]
  }

  TestSuite instproc destroy args {
    if {[my exists node]} {
      [[my set node] ownerDocument] delete
    }
    next
  }


  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /
  
  # / / / / / / / / / / / / / /
  # Class TestCase
  
  Class TestCase -superclass {
    Guardian
    Fixture
  } -array set defaults {
    name		{[namespace tail [self]]}
    classname		""
    time		""
    scenarios		0
    errors		0
    failures		0
  }
  TestCase instproc init args {
    my halt_on_first_error 1
    next
  }
  TestCase instproc report {{-stop:switch false} result} {
    if {$stop} {
      # / / / / / / / / / / / / / /
      # aggregates go here!
      my incr attributes(scenarios)
      if {[$result istype Unsatisfied]} {
	my incr attributes(errors)
      }
      if {[$result istype Failure]} {
	my incr attributes(failures)
      }
    }
    #ns_write "[self] REPORT args=$result, stop=$stop\n"
    next;# Test->report
  }

  TestCase instproc getNode {} {
    return [next [string tolower [namespace tail [self class]]]];# Test->getNode
  }

  TestCase instproc run {} {
    my instvar node
    my set timestamp [Timestamp new -destroy_on_cleanup]
    [self class] instvar defaults
    if {![info exists node]} {
      set node [my getNode]
      my array set attributes [array get defaults]
    }
    #ns_write "[self]: RUN\n"
    if {![catch {next} msg]} {
      my finalise
      my satisfied [Satisfied new "done"]
    } else {
      error $msg
    }
  }


  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /

  # / / / / / / / / / / / / / /
  # Class TestScenario
  
  Class TestScenario -slots {
    Attribute test_body
    Attribute expected_result
  } -superclass Test \
      -array set defaults {
	name		{[namespace tail [self]]}
	type		{[namespace tail [my info class]]}
	message		{}
	description	{[string trim [my set description]]}
	nettime		0
      }

  TestScenario instmixin add Guardian

  TestScenario instproc report {{-stop:switch false} result} {
    #ns_write "[self] REPORT args=$result,stop=$stop\n"
    next;# Test->report
  }

  TestScenario instproc getNode {} {
    return [next [string tolower [namespace tail [self class]]]];# Test->getNode
  }

  TestScenario instproc run {} {
    my instvar test_body
    my instvar node
    my set timestamp [Timestamp new -destroy_on_cleanup]
    [self class] instvar defaults
    if {![info exists node]} {
      set node [my getNode]
      my array set attributes [array get defaults]
    }
    next;# Guardian->run
    if {[info exists test_body]} {
     # ns_write "[self]: RUN\n"
      my evaluate $test_body
    }
  }

  TestScenario instproc evaluate {test_body} {
    my instvar expected_result
    if {![info exists expected_result]} {
      set msg "No 'expected_result' provided for comparand scenario."
      my unsatisfied [Unexpected new $msg]
    }
    set ts [Timestamp new -volatile]
    if {[catch { set r [my mockEval $test_body] } msg]} {
      # / / / / / / / / / / / /
      # A failing mock eval at
      # this point represents
      # an unsatisfying, 'error'
      # condition
      my unsatisfied [Unexpected new $msg]
    } else {
      my set attributes(nettime) [$ts diff]
      if {$r ne $expected_result} {
	#ns_write UNSATISFIED\n
	my unsatisfied [Unsatisfied new "$r != $expected_result"]
      } else {
	#ns_write SATISFIED\n
	my satisfied [Satisfied new "$r == $expected_result"]
      }
    }
  }

  TestScenario instproc report {{-stop:switch false} result} {
    #ns_write "[self]: REPORT,stop=$stop\n"
    my instvar node
    my set attributes(type) [namespace tail [$result info class]]
    my set attributes(message) [$result message]
    my finalise
    next
  }

  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /

  # / / / / / / / / / / / / / /
  # Class TestResult
  
  Class TestResult -slots {
    Attribute reference -default {}
    Attribute message -default {}
  }
  TestResult instproc init msg {
    my destroy_on_cleanup
    my message $msg
    next
  }
  TestResult instproc = {object} {
    my instvar reference
    #ns_write REF($reference==$object)=[expr {$reference eq $object}]\n
    return [expr {$reference eq $object}]
  }
  Class Unsatisfied -superclass TestResult 
  Class PrerequisiteUnsatisfied -superclass Unsatisfied
  Class ConditionUnsatisfied -superclass Unsatisfied
  Class Unexpected -superclass Unsatisfied
  Class Satisfied -superclass TestResult 
  

  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /
  # / / / / / / / / / / / / / /

  # / / / / / / / / / / / / / /
  # Class FailureScenario
  # - - - - - - - - - - - - - - 
  # These are test scenarios
  # that are satisfied by 'false
  # negatives'. We, especially, use
  # them for testing exception
  # settings.
  
  Class Failure -superclass Satisfied

  Class FailureScenario -superclass TestScenario
  FailureScenario instproc evaluate {test_body} {
    my instvar expected_result
    if {![info exists expected_result]} {
      set msg "No 'expected_result' provided for comparand scenario."
      my unsatisfied [Unexpected new $msg]
    }
    set ts [Timestamp new -volatile]
    if {[catch { set r [my mockEval $test_body] } msg]} {
      my set attributes(nettime) [$ts diff]
      if {[my isobject $msg] && [$msg istype $expected_result]} {
	my satisfied [Failure new [$msg message]]
      } elseif {[my isobject $msg]} {
	my unsatisfied [Unsatisfied new [$msg info class]]
      } else {
	my unsatisfied [Unexpected new $msg]
      }
    } else {
      my unsatisfied [Unsatisfied new "Did not produce a false negative."]
    }
  }

  # / / / / / / / / / / / / / /
  # Class NonFailureScenario
  # - - - - - - - - - - - - - - 
  # A simple testscenario which simply
  # requires the test body to execute
  # without errors/excpetions being fired.

  Class NonFailureScenario -superclass TestScenario
  NonFailureScenario instproc evaluate {test_body} {
    set ts [Timestamp new -volatile]
    if {[catch { set r [my mockEval $test_body] } msg]} {
      my set attributes(nettime) [$ts diff]
      # failed
      if {[my isobject $msg]} {
	my unsatisfied [Unsatisfied new [$msg message]]
      } else {
	my unsatisfied [Unsatisfied new $msg]
      }
    } else {
      # succeeded
      my satisfied [Satisfied new "Ran smoothly without errors/exceptions."]
    }
  }


  # / / / / / / / / / / / / / /
  # a custom aggregator at
  # the TestCase level
  Class FailureScenario::TestCase 
  FailureScenario::TestCase instproc report {{-stop:switch false} result} {
    if {$stop} {
      if {[$result istype Failure]} {
	my incr attributes(failures)
      }
    }
    next
  }

  TestCase instmixin add FailureScenario::TestCase
    
  namespace export TestSuite TestCase TestScenario \
      TestResult
}
