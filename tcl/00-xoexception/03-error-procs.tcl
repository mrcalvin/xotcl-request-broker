
#package provide xoexception::Error 1.0

#package require xoexception::Throwable

namespace eval ::xoexception {

    ::xotcl::Class create Error -superclass Throwable -ad_doc {

        Error is the base class for all errors in 
        xoexception. An error can be thrown using "error":

        error [ ::xoexception::Error new "Some message" ]

        Error is not a subclass of Exception. This is to
        allow a different error handling mechanism for Errors.

        An Error represents a major problem in the code, that
        cannot be handled by the application. The error handling
        code should alert the user in some fasion that the error
        has occured and may ask the user for a course of action to 
        follow.
      }

    namespace export Error
  }
