#package provide xoexception::Throwable 1.0

#package require xoexception

namespace eval ::xoexception {

    namespace import -force ::xotcl::*

    ::xotcl::Class create Throwable -ad_doc {

        Throwable is the base class for all objects that can be
        thrown in xoexception. Throwables are objects that are thrown
        with the Tcl "error" command.  Instead of throwing string
        errors, exception objects can be thrown that contain
        more information that an unformatted string. 

        To throw an exception use:

        error [ Throwable new "Some error has occured" ]

        This can be used with a catch statement:

        if [ catch {

            error [ Throwable new "error" ]

        } result ] {

            puts "Caught exception. Message is [ $result message ]"
        }

        Throwable also provides some facilities to work with exceptions.

        isThrowable is used to determine if a catch-result is an 
        exception object or a unformatted string.

        Throwable isThrowable "some string"
        
        returns 0

        Throwable isThrowable [ Throwable new "error" ]

        returns 1

        extractMessage is used to get the message from an Throwable or
        from an unformatted string.

        if [ catch {

        #Some error happens here. It might throw an Throwable or an string.


        } result ] {
            #It doesnt matter if the result is a string or Throwable object.
            puts "[ Throwable extractMessage $result ]"
        }

        try is an extension of catch that can catch certain types of 
        Throwables.  

        try {
            #Code that could possibly thrown an error.
            #The exceptions can be called in this block or
            #in procs within this block.
        } catch {Error e1} {
            #Handle the error here if the error thrown is of
            #type Error or a subclass of Error.
            #More specific exceptions must come first in 
            #the blocks as these blocks are queried in top-to-bottom
            #order. Error is a subclass of Throwable so any Error
            #instance is also an Throwable instance and would always
            #be handled by the next block.
        } catch {Throwable e2} {      
            #Handle the error here if the error thrown is of
            #type Throwable or a subclass of Throwable.
        } catch {error e3} {   
            #try/catch can also catch unformatted string errors.
            #Use the type "error" to catch string errors.
        } finally {                                 
            #Finally blocks are optional.  They are always called
            #after all of the catch blocks are called, and even if 
            #they are not called.
        }
      }

    #Throwable # message { The message that is carried with the Throwable. }
    #Throwable # trace { The stack trace that was recorded when the Throwable was created }

    Throwable parameter {
        message
        stack
    }

    Throwable ad_instproc init { { message "" } } { 

        Constructor that creates a new Throwable object with a message.
        The default message is blank.
    } {

        ::xotcl::my message $message
        ::xotcl::my stack ""
    }

    #Throwable # isThrowable 
    Throwable ad_proc isThrowable { message {className ::xoexception::Throwable } } { 

        Returns 1 if the message is an exception object, 0 otherwise.
        This is useful in determining if a message is an unformatted
        string or an object reference.  Optionally className can
        be specified that determines if the exception is an instance of
        a subclass of that class.
    } {

        set return 0

        if { ![ ::xotcl::Object isobject $message ] } {

           return 0
        }

        #catch {
            if { [$message istype $className ] } {

                set return 1
            }
        #}

        return $return
      }

    #Throwable # extractMessage
    Throwable ad_proc extractMessage { message  }  { 

        Extracts a string message from an Throwable object
        or from an unformatted string.  This is useful
        to get the error message without caring if the
        the message was an Throwable or an unformatted string.
    } {

        if [ ::xoexception::Throwable::isThrowable $message ] {

            set message [ $message message ]
        }

        return $message
    }

    #Throwable # try 

    Throwable ad_proc try { script args } { 

        try is an extension of the catch proc it allows
        for multiplexing the error handling code with
        Throwable types. 

        try catches the error and then uses the class of
        the error to determine which block of error handling
        code should execute. If an error is an object try
        uses the first catch statement that has the class
        or a superclass of the object.  For instance
        if a catch block was

        try {

        } catch { ::xoexception::Exception e } {

        }

        only errors that refer to instances of Exceptions
        or subclasses of Exceptions would be handled by this block.

        try can also handle not object errors.  It does so with
        the "error" type.

        try { 
            error "some string error"
        } catch { error e } {
            puts "Error: $e"
        }

        try also works with errorInfo:

        try { 
            error "some string error"
        } catch { error e } {
            global errorInfo
            puts "Error: $e\n$errorInfo"
        }

        Example:

        try {

            error [ ::xoexception::Exception new "Ouch" ]
            
        } catch {Error e1} {
            #This block is not called because Exception is not
            #a subclass of Error.
            puts "Error [ $e1 message ]"
        } catch {Throwable e2} {      
            #This block is called because Exception is a subclass
            #of Throwable.
            puts "Throwable [ $e2 message ]"
        } catch {error e3} {   
            #try/catch can also catch unformatted string errors.
            #Use the type "error" to catch string errors.
            #This block is not called because the previous block
            #matched the Exception type.
        } finally {                                 

            #finally blocks are always called.
            #put essential clean up code here.
            puts "Done with try/catch/finally"
        }
    } {

        set remainingArgs $args
        set retValue [ catch "uplevel {$script}" result ]
	set finallyScript ""
        set runACatchBlock 1

        if { 0 == $retValue } {

            set runACatchBlock 0
        }

        switch $retValue {

            3 { error "break not supported in try without loop" }
            4 { error "continue not supported in try without loop" }
            2 { error "return not supported in try" }
            0 -
            1 { 
                while { [ llength $remainingArgs ] != 0 } {

                    set firstArg [ lindex $remainingArgs 0 ]

                    switch $firstArg {

                        catch { 

                            set errorTypeAndName [ lindex $remainingArgs 1 ]
                            set errorType [ lindex $errorTypeAndName 0 ]
                            set errorName [ lindex $errorTypeAndName 1 ]
                            set catchScript [ lindex $remainingArgs 2 ]
                            set remainingArgs [ lrange $remainingArgs 3 end ]

                            if { $runACatchBlock } {

                                if { "error" == "$errorType" } {

                                    uplevel [ list set $errorName $result ]
                                    uplevel $catchScript
                                    set runACatchBlock 0

                                } elseif [ ::xoexception::Throwable::isThrowable $result $errorType ] {

                                    uplevel [ list set $errorName $result ]
                                    uplevel $catchScript
                                    set runACatchBlock 0

                                } elseif { "onlyerror" == "$errorType" && ! [ ::xoexception::Throwable::isThrowable $result ] } {
                                    uplevel [ list set $errorName $result ]
                                    uplevel $catchScript
                                    set runACatchBlock 0
                                }
                            }
                        }

                        finally { 

                            if { "" != "$finallyScript" } {

                                error "try may only have one finally block"
                            }

                            set finallyScript [ lindex $remainingArgs 1 ]
                            set remainingArgs [ lrange $remainingArgs 3 end ]
                        }

                        default { error "Expected catch or finally in try" }
                    }
                }

                uplevel $finallyScript

                if { $runACatchBlock } {

                    if [ ::xoexception::Throwable::isThrowable $result ] {

                        error $result

                    } else {

                        global errorInfo
                        error $errorInfo
                    }
                }

                return $result
            }
            default { error "return code $retValue not supported" }
        }
    }

    namespace export Throwable

  }
