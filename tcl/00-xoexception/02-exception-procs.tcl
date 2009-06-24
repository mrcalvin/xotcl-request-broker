#package provide xoexception::Exception 1.0

#package require xoexception
#package require xoexception::Throwable

namespace eval ::xoexception {

    ::xotcl::Class create Exception -superclass Throwable -ad_doc {

        Exception is the base class for all exceptions in 
        xoexception. An exception can be thrown using "error":

        An Exception represents an exceptional case in the application
        state.  This state happens infrequently enough that it 
        should not be checked explicitly.  Exceptions can also
        be used to stop execution of code and jump to exception
        handling code.  This removes any need for the GOTO 
        command in code. Exceptions can also pass information
        between code.  XOUnit uses this functionality.  Exceptions
        are used to flag failures in tests. The lack of an Exception
        during test execution is a test pass.

        error [ ::xoexception::Exception new "Some message" ]

        The exception can be caught using "catch":

        if [ catch {
            error [ ::xoexception::Exception new "Some message" ]
        } result ] {
            puts "Exception: [ $result message ]"
        }

        The exception can be caught using "::xoexception::try":

        ::xoexception::try {
            error [ ::xoexception::Exception new "Some message" ]
        } catch { ::xoexception::Exception e } {
            puts "Exception: [ $e message ]"
        }

        or can be caught with try by catching Throwable

        ::xoexception::try {
            error [ ::xoexception::Exception new "Some message" ]
        } catch { ::xoexception::Throwable t } {
            puts "Throwable: [ $t message ]"
        }
      } -instproc init args {
	# / / / / / / / / / / / / /
	# provide for auto-cleanup
	my destroy_on_cleanup
      }
    namespace export Exception
}
