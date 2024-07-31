import "fcgiCodec"


// Initialize network.

srv = uds.createServer("/tmp/fcgiCodec-example.sock")

print "Listening at /tmp/fcgiCodec-example.sock ..."


// Create a RecordDecoder to convert raw socket data into `Record` objects.

decoder = fcgiCodec.RecordDecoder.make


// Create a Bucket to collect the data for each individual request (it will also convert `Record` objects into appropriate `*Msg` objects).

bucket = fcgiCodec.Bucket.make


// Our state:
n = 0  // we'll increment it on each request

conn = null

while true
	
	yield
	
	print "Waiting for connection... ", ""
	
	if conn == null then conn = srv.accept(-1)  // wait for Nginx to make a connection to us
	
	print "OK"
	print "Waiting for data... ", ""
	
	data = conn.receive(-1, -1)  // wait for Nginx to send us request data
	
	if data == null then continue
	
	print "OK. Got " + data.len + " bytes."
	
	
	// Convert data into records via the decoder, and put those records into the bucket.
	
	decoder.pushData data
	
	records = decoder.getAllRecords
	
	print "Decoded " + records.len + " records."
	
	bucket.pushManyRecords records
	
	
	// Writing a callback for `Bucket.handleAll()`.
	
	closeP = false
	
	handler = function(request, arg)
		
		print "Handling request #" + request.requestId + "..."
		
		// Here we might expect to meet some special cases:
		//  - Management message
		//  - Unfinished request
		//  - Aborted request
		//  - Unknown role
		//  ...
		
		// For the sake of simplicity we'll only cover regular requests of a "responder" role.
		
		
		// Did we read the params yet?
		
		if request.params == null then return false  // false: we're not done with the request, keep it in the bucket
		
		
		// Touch state
		
		outer.n += 1
		
		
		// Compose a response
		
		rsp = "Content-Type: text/html" + char(13) + char(10) +
		      "" + char(13) + char(10) +
		      "<h1>hello fcgiCodec ({n})</h1> params: {params}"
		rsp = rsp.replace("{n}", outer.n)
		rsp = rsp.replace("{params}", str(request.params))
		
		
		// Return response to Nginx
		
		msg = fcgiCodec.StdoutMsg.make(request.requestId, rsp)
		for record in msg.toRecords
			conn.send record.toRawData  // return "CGI stdout"
		end for
		
		msg = fcgiCodec.EndRequestMsg.make(request.requestId, 0, fcgiCodec.protoStatus.FCGI_REQUEST_COMPLETE)
		for record in msg.toRecords
			conn.send record.toRawData  // tell Nginx that we're done
		end for
		
		if not request.keepConnectionP then outer.closeP = true  // did Nginx ask us to close the connection?
		
		return true  // true: we're done with this request, delete it from the bucket
		
	end function
	
	
	// Handle requests (if any).
	
	bucket.handleAll null, @handler
	
	
	if closeP then
		conn.close
		conn = null
		closeP = false
	end if
	
end while
