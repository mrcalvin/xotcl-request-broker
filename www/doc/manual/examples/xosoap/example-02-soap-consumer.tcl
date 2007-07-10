# -) prerequisites
namespace import ::xosoap::client::*

# 1-) create a combined 'client proxy' + 'glue' object
SoapObject EchoClient\
    -endpoint "http://websrv.cs.fsu.edu/~engelen/interop2.cgi"\
    -action "http://websrv.cs.fsu.edu/~engelen/interop2.cgi" \
    -callNamespace http://soapinterop.org/ \
    -messageStyle ::xosoap::RpcEncoded

# 2-) create the interface of the 'client proxy'
EchoClient ad_proc -returns xsFloat\
    echoFloat {
      -inputFloat:xsFloat,glue
    } {
      By calling this proc, a remote call is issued \
	  against the previously defined endpoint
    } {}

# 3-) issue the call
ns_write [EchoClient echoFloat -inputFloat 1.61805]




