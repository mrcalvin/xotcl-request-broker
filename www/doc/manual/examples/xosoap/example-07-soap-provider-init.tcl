# / / / / / / / / / / / / / / / / / / / / / / / / / /
# $Id$

# -) prerequisites
namespace eval ::xorb::manual {
  namespace import ::xorb::*

  # 1-) provide an interface description: 'service contract'
  ServiceContract EchoService -defines {
    Abstract echoFloat \
	-arguments {
	  inputDate:xsFloat
	} -returns returnValue:xsFloat \
	-description {
	  Here, we outline an abstract call "echoFloat"
	  and its basic characteristics to be realised
	  both by servant code and client proxies.
	}
  } -ad_doc {
    This contract describes the interface of the 
    EchoService example service as introduced by
    xorb's manual.
  }
  
  # 1a-) deploy your interface description
  EchoService deploy
  
  # 2-) Provide 'servant' code and register it with the invoker: 
  # 'service implementation'
  ServiceImplementation EchoServiceImpl \
      -implements EchoService \
      -using {
	Method echoFloat {
	  -inputFloat:required
	} {Echoes an incoming float} {
	  return $inputFloat
	}
      }
  
  # 3a-) deploy your service implementation
  EchoServiceImpl deploy
}