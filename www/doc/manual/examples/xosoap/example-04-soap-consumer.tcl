# -) prerequisites
namespace import ::xosoap::client::*
namespace import ::xorb::stub::*

# 1-) create and populate a 'glue' object
set glueObject [SoapGlueObject new \
		    -endpoint "http://websrv.cs.fsu.edu/~engelen/interop2.cgi"\
		    -action "http://websrv.cs.fsu.edu/~engelen/interop2.cgi" \
		    -callNamespace http://soapinterop.org/ \
		    -messageStyle ::xosoap::RpcEncoded]

# 2-) create a 'client proxy'
ProxyObject EchoClient -glueobject $glueObject

# 3-) create the interface of the 'client proxy'
EchoClient ad_proc -returns xsFloat \
    echoFloat {-inputFloat:xsFloat,glue} \
    {
      By calling this proc, a remote call is issued \
	  against the previously defined endpoint. \
	  However, this time, the call only gets executed \
	  when the floating number matches a certain value \
	  space.
    } {
      if {[expr {round(0.5 * (1 + sqrt(5)))}] == [expr round($inputFloat)]} {
	next;# invoke on remote method / procedure
      }
    }

# 4-) issue the call
ns_write [EchoClient echoFloat -inputFloat 1.6180339887]
