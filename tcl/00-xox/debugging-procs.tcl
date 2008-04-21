::xo::library doc {

  Adapted from xotcllib, see 
  http://xotcllib.cvs.sourceforge.net/xotcllib/xox
  Slightly adapted for OpenACS deployment by
  stefan.sobernig@wu-wien.ac.at; 
  see LICENCE for distribution-specific details.

  @author ben.thomasson@gmail.com
  
}
#package require XOTcl

namespace eval ::xox {

  Class Debugging  -ad_doc { Mixin that provides the debug method }
  #Debugging # stackTrace 

  Debugging ad_instproc stackTrace { } { Return the full stack trace.} {

      append buffer "\n"

      set currentLevel [ self callinglevel ]

      if [ string match "#*" $currentLevel ] {

          set numberLevel [ string range $currentLevel 1 end ]

      } else {
          return
      }

      for { set loop $numberLevel } { $loop >= 1 } { incr loop -1 } {

          set args ""
          set class [ uplevel #$loop ::xotcl::self class ]
          set method [ uplevel #$loop ::xotcl::self proc ]
          if [ Object isclass $class ] {
              catch {
              set args ""
              set args [ $class info instargs $method ]
              }
          }
          append buffer "#$loop. $class->$method \{$args\}"
          append buffer "\n"
      }

      return $buffer
  }

  Object instmixin add ::xox::Debugging
}

#package provide xox::Debugging 1.0

