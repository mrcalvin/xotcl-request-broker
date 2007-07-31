# -) prerequisites
namespace import ::xosoap::client::*

# 1-) we define a distinct glue object

set glueObject [SoapGlueObject new \
		    -endpoint "http://dietrich.ganx4.com/nusoap/testbed/round2_base_server.php"\
		    -messageStyle ::xosoap::RpcEncoded]

# 2-) create a combined 'client proxy' + 'glue' object
SoapObject EchoClient\
    -endpoint "http://websrv.cs.fsu.edu/~engelen/interop2.cgi"\
    -action "http://websrv.cs.fsu.edu/~engelen/interop2.cgi" \
    -callNamespace http://soapinterop.org/ \
    -messageStyle ::xosoap::RpcEncoded

# 3-) create the interface of the 'client proxy'
EchoClient ad_proc -glueobject $glueObject -returns xsFloat\
    echoFloat {
      -inputFloat:xsFloat
    } {
      By calling this proc, a remote call is issued \
	  against the previously defined endpoint
    } {}

# 4-) issue the call
ns_write [EchoClient echoFloat -inputFloat 1.61805]




