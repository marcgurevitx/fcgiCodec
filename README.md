# FcgiCodec

`fcgiCodec` is a library for the [MiniScript](https://miniscript.org/) programming language that encodes and decodes [FastCGI](https://fastcgi-archives.github.io/FastCGI_Specification.html) protocol messages.

This is not a full-fledged FastCGI library that would manage the network, only encoding and decoding of the data is covered.

Your platform should have an implementation of a [RawData](https://miniscript.org/wiki/RawData) class.


## Install

You only need this file: `lib/fcgiCodec.ms`.


## Tests

Run `./mm-test.sh` to test in Mini Micro.

Run `./cl-test.sh` to test in command-line.


## Example of a FastCGI server

This example is a MiniScript program sitting behind Nginx, serving HTTP pages. Each new page displays a number which gets incremented on each request.

Notes:

- The MiniScript interpreter for this example is patched to support [unix domain sockets](https://en.wikipedia.org/wiki/Unix_domain_socket) via [uds](https://github.com/marcgurevitx/miniscript-by-jjs/blob/unix-domain-sockets/MiniScript-cpp/README-UDS.md) module.
- Nginx configuration here is very minimal, apart from `listen`, it's just a single `fastcgi_pass` instruction: `fastcgi_pass unix:/tmp/fcgiCodec-example.sock;`.
- When this program launches, it *recreates* the socket file and apparently Nginx can't write to it due to how permissions for new files work on my machine. So, what I personally do is I change the permission flags to `a+w` with my human hands. Hey, I'm a coder, not a devops.
- For the sake of brevity the error checking is omitted and various special cases not handled.

<details>

<summary>See code...</summary>

```c
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
```
</details>

---

![in browser](/data/fcgiCodecExample.gif)


## Overview

FastCGI client and server exchange data which are packed in binary structures named "records".

This library provides two classes to manage such records in code: `Record` class and `RecordDecoder` class.

To create a record object, call `Record.make()` factory. Then, to get its raw bytes, call `toRawData()` method.

If you have a stream of records encoded in raw data and you want to get individual records out of it, create a decoder using `RecordDecoder.make()` factory, feed the data you have into it using its `pushData()` method and then collect the resulted `Record` objects using `getRecord()` or `getAllRecords()` methods.

These two classes provide a simple API, but it has a couple of disadvantages:

- Records only know about their `recordType`, `requestId` and `body`, the type specific info is not parsed (you can easily craft a record with a nonsense body).
- "Stream" handling -- breaking and glueing together the payload of successive stream record types -- has to be done manually.

To overcome these problems use `*Msg` classes ("messages"). They're like `Record` class but with type specific properties for each record type that you can read or modify. Also, the stream records have their bodies glued together into a single data chunk under one message object. To create a message, call `make()` factory of a particular message class. See below what properties each of the `*Msg` classes has.

There's no special method to generate the `RawData` of a message, instead use `toRecords()` method first and then call `toRawData()` of each record. There's also no method to parse messages from a `RawData` stream (I didn't need it, so I didn't code it) -- however, if you have records and want to convert them into messages, you can do it by using a `Bucket` object.

The `Bucket` class helps with the multiplexed/interleaved workflow when the client may send FastCGI records for several requests simultaneously. You add records to a `Bucket` using its `pushRecord()` method and then you handle *requests* using `handleOne()` or `handleAll()` methods.

The request objects accumulated by a `Bucket` are not instances of some class but just adhoc maps with messages as the values, plus some properties. (Note that if your code is running on the client side and is consuming data from a server, then what you get is not technically requests but *responses*, but `Bucket` doesn't care.)

`NameValuePairs` class is handy with record types that encode their body in a "name-value pairs" format (\<NAME_LENGTH> \<VALUE_LENGTH> \<NAME> \<VALUE> ... etc). Most of the times, `NameValuePairs` objects don't need to be created directly but instead are exposed through `*Msg` or request objects. However, you also can create one yourself by calling `NameValuePairs.make()` factory. Also, no one will stop you from using `NameValuePairs` on their own outside FastCGI context just for serialization of flat name-value maps.

To manage name-value pairs use `hasName()`, `getValue()`, `setValue()` and `deleteValue()` methods. If you want to parse name-value pairs from `RawData` chunks, use the `pushData()` method, and to get the raw bytes, call `toRawData()` method.

One more note about `NameValuePairs` class: whatever data you put into it (via `setValue()` or `pushData()`), both the keys and the values will always be converted to strings.

Also, if a method of some class accepts `RawData` as a parameter, it also will happily accept a string and convert to `RawData` behind the scenes.

Finally, if you read the code, you'll find a `RawDataCollection` class which is used for gluing and slicing `RawData` chunks. Very handy, you probably don't need to manipulate it directly.


## Record class

`Record` class represents a FastCGI record.

| Property / method | Description |
| --- | --- |
| `recordType` | record type from `fcgiCodec.recordType` enum |
| `requestId` | request ID (`0` for management types) |
| `make()` (class method) | returns a new `Record` object |
| `body()` | returns `RawData` of the record body |
| `toRawData()` | returns `RawData` of the entire record (head + body) |

Constants in `fcgiCodec.recordType` enum (same numbers as in the specification):

```c
recordType.FCGI_BEGIN_REQUEST = 1
recordType.FCGI_ABORT_REQUEST = 2
recordType.FCGI_END_REQUEST = 3
recordType.FCGI_PARAMS = 4
recordType.FCGI_STDIN = 5
recordType.FCGI_STDOUT = 6
recordType.FCGI_STDERR = 7
recordType.FCGI_DATA = 8
recordType.FCGI_GET_VALUES = 9
recordType.FCGI_GET_VALUES_RESULT = 10
recordType.FCGI_UNKNOWN_TYPE = 11
```

#### Record.make()

`Record.make(recordType, requestId = 0, body) -> Record`

(Class method) Returns a new `Record` object.

The `body` argument can be a `RawData` object or a string.

This method doesn't parse or check the `body`. To ensure correctness of type specific properties use `*Msg` classes.

---

#### record.body()

`record.body() -> RawData`

Returns `RawData` of the record body.

---

#### record.toRawData()

`record.toRawData() -> RawData`

Returns `RawData` of the entire record (head + body).

---


## RecordDecoder class

`RecordDecoder` class can be used to read a raw data stream and extract `Record` objects from it.

| Property / method | Description |
| --- | --- |
| `make()` (class method) | returns a new `RecordDecoder` object |
| `pushData()` | appends a raw data chunk to the inner data stream |
| `getRecord()` | take one record from the stream (if available) |
| `getAllRecords()` | take all available records from the stream |

#### RecordDecoder.make()

`RecordDecoder.make() -> RecordDecoder`

(Class method) Returns a new `RecordDecoder` object.

---

#### recordDecoder.pushData()

`recordDecoder.pushData(r, onError = null) -> null | onError result`

Appends a raw data chunk to the inner data stream.

The parsing starts immediately and decodes as many records as available.

When there's not enough data for a whole record, the parsing stops till the next call to `pushData()` brings more input.

If the parsing encounters errors, the default action is `qa.abort()` (it means, it crashes the program).

If `onError()` callback is supplied, it gets called instead of `qa.abort()` (it means, it prevents the crash).

The `onError()` callback should have at least these parameters: `onError(errCode, arg1)`.

The following error conditions are reported:

| Error code (`errCode`) | Description |
| --- | --- |
| `"UNKNOWN_PROTO"` | the protocol byte (0) has an unknown value, `arg1` holding the value |
| `"UNKNOWN_RECORD_TYPE"` | the record type byte (1) has an unknown value, `arg1` holding the value |

The return value of the `onError()` callback becomes the return value of `pushData()`.

After the error, the `RecordDecoder` object becomes unusable, because it can't move past the erroneous bytes.

If no errors are encountered or if `onError()` returns `null`, the result of `pushData()` is `null`.

---

#### recordDecoder.getRecord()

`recordDecoder.getRecord() -> Record | null`

Take one record from the stream (if available).

---

#### recordDecoder.getAllRecords()

`recordDecoder.getAllRecords() -> list of Record objects`

Take all available records from the stream.

---


## *Msg classes

Message classes handle type related properties of records, join stream records into a single object and decode name-value pairs of certain record types.

Each record type has a corresponding message class (they all have predictable names).

| Record type | Class |
| --- | --- |
| `recordType.FCGI_BEGIN_REQUEST` | `BeginRequestMsg` |
| `recordType.FCGI_ABORT_REQUEST` | `AbortRequestMsg` |
| `recordType.FCGI_END_REQUEST` | `EndRequestMsg` |
| `recordType.FCGI_PARAMS` | `ParamsMsg` |
| `recordType.FCGI_STDIN` | `StdinMsg` |
| `recordType.FCGI_STDOUT` | `StdoutMsg` |
| `recordType.FCGI_STDERR` | `StderrMsg` |
| `recordType.FCGI_DATA` | `DataMsg` |
| `recordType.FCGI_GET_VALUES` | `GetValuesMsg` |
| `recordType.FCGI_GET_VALUES_RESULT` | `GetValuesResultMsg` |
| `recordType.FCGI_UNKNOWN_TYPE` | `UnknownTypeMsg` |

The common API of all `*Msg` classes:

| Property / method | Description |
| --- | --- |
| `recordType` | record type from `fcgiCodec.recordType` enum |
| `requestId` | request ID (`0` for management types) |
| `make()` (class method) | returns a new message object (the signature of this method will be different for each class) |
| `toRecords()` | returns a list of records that form the message |

Other properties are defined by the parameters to `make()`.

#### BeginRequestMsg.make()

`BeginRequestMsg.make(requestId, role, keepConnectionP) -> BeginRequestMsg`

(Class method) Returns a new `BeginRequestMsg` object and sets its properties.

| Parameter / property | Description |
| --- | --- |
| `requestId` | request ID |
| `role` | FastCGI role from `fcgiCodec.role` enum |
| `keepConnectionP` | if true, the server should close a network connection after serving the request |

Constants in `fcgiCodec.role` enum (same numbers as in the specification):

```c
role.FCGI_RESPONDER = 1
role.FCGI_AUTHORIZER = 2
role.FCGI_FILTER = 3
```

---

#### AbortRequestMsg.make()

`AbortRequestMsg.make(requestId) -> AbortRequestMsg`

(Class method) Returns a new `AbortRequestMsg` object and sets its properties.

| Parameter / property | Description |
| --- | --- |
| `requestId` | request ID |

---

#### EndRequestMsg.make()

`EndRequestMsg.make(requestId, appStatus, protoStatus) -> EndRequestMsg`

(Class method) Returns a new `EndRequestMsg` object and sets its properties.

| Parameter / property | Description |
| --- | --- |
| `requestId` | request ID |
| `appStatus` | CGI program exit status |
| `protoStatus` | protocol status from `fcgiCodec.protoStatus` enum |

Constants in `fcgiCodec.protoStatus` enum (same numbers as in the specification):

```c
protoStatus.FCGI_REQUEST_COMPLETE = 0
protoStatus.FCGI_CANT_MPX_CONN = 1
protoStatus.FCGI_OVERLOADED = 2
protoStatus.FCGI_UNKNOWN_ROLE = 3
```

---

#### ParamsMsg.make()

`ParamsMsg.make(requestId, paramsMap) -> ParamsMsg`

(Class method) Returns a new `ParamsMsg` object and sets its properties.

| Parameter / property | Description |
| --- | --- |
| `requestId` | request ID |
| `paramsMap` | map of CGI params |

---

#### StdinMsg | StdoutMsg | StderrMsg | DataMsg .make()

`StdinMsg.make(requestId, data) -> StdinMsg`

`StdoutMsg.make(requestId, data) -> StdoutMsg`

`StderrMsg.make(requestId, data) -> StderrMsg`

`DataMsg.make(requestId, data) -> DataMsg`

(Class method) Returns a new `*Msg` object and sets its properties.

| Parameter / property | Description |
| --- | --- |
| `requestId` | request ID |
| `data` | raw data body |

---

#### GetValuesMsg.make()

`GetValuesMsg.make(names) -> GetValuesMsg`

(Class method) Returns a new `GetValuesMsg` object and sets its properties (`requestId = 0`).

| Parameter / property | Description |
| --- | --- |
| `names` | list of requested variable names |

---

#### GetValuesResultMsg.make()

`GetValuesResultMsg.make(valuesMap) -> GetValuesResultMsg`

(Class method) Returns a new `GetValuesResultMsg` object and sets its properties (`requestId = 0`).

| Parameter / property | Description |
| --- | --- |
| `valuesMap` | map of requested variables |

---

#### UnknownTypeMsg.make()

`UnknownTypeMsg.make(unknownType) -> UnknownTypeMsg`

(Class method) Returns a new `UnknownTypeMsg` object and sets its properties (`requestId = 0`).

| Parameter / property | Description |
| --- | --- |
| `unknownType` | unknown type |

---

#### msg.toRecords()

`msg.toRecords(chunkLength = null) -> list of Record objects`

Returns a list of records that form the message.

The list will contain one record for non-stream record types, and two or more records for stream record types (the last of such records will always have an empty body).

An optional `chunkLength` parameter only makes sense for stream types and ignored for other types.

If given, it denotes a maximal length of each individual record body. If `null`, a whole body is encoded as a single record, followed by an empty-body record.

---


## Bucket class

`Bucket` can be used to collect `Record` objects and to build *"request"* objects -- adhoc collections of messages.

The `Bucket`'s workflow is different from the decoder's in that you don't take a request from a bucket, but *handle* it in place.

The reason for this is that the server is allowed to start responding to a request before all messages are received.

| Property / method | Description |
| --- | --- |
| `make()` (class method) | returns a new bucket object |
| `nRequests()` | returns number of requests in a bucket |
| `requestIds()` | returns a list of request IDs |
| `pushRecord()` | appends a `Record` object to the inner state |
| `pushManyRecords()` | appends a list of `Record` objects to the inner state |
| `handleOne()` | handles a request object |
| `handleAll()` | handles all request objects |
| `removeRequest()` | deletes a request object from a bucket and returns it |

#### Bucket.make()

`Bucket.make() -> Bucket`

(Class method) Returns a new `Bucket` object.

---

#### bucket.nRequests()

`bucket.nRequests() -> number`

Returns number of requests in a bucket.

---

#### bucket.requestIds()

`bucket.requestIds() -> list of request IDs`

Returns a list of request IDs.

---

#### bucket.pushRecord()

`bucket.pushRecord(record, onError = null) -> null | onError result`

Appends a `Record` object to the inner state.

The record is checked for its type and a corresponding message object is created and saved inside a bucket.

Unfinished messages are saved separately till the next call to `pushRecord()` brings more records.

If the conversion to a message encounters errors, the default action is `qa.abort()` (it means, it crashes the program).

If `onError()` callback is supplied, it gets called instead of `qa.abort()` (it means, it prevents the crash).

The `onError()` callback should have at least these parameters: `onError(errCode, arg1, arg2)`.

The following error conditions are reported:

| Error code (`errCode`) | Description |
| --- | --- |
| `"DIRTY_BUCKET"` | a message with the same record type (`arg1`) and request ID (`arg2`) already exists in the bucket |
| `"BODY_TOO_SHORT"` | not enough bytes in a record body to parse its properties, need `arg1` bytes, got `arg2` bytes |
| `"UNKNOWN_ROLE"` | the role bytes (0-1) of a `FCGI_BEGIN_REQUEST` record body have an unknown value, `arg1` holding the value |
| `"UNKNOWN_PROTO_STATUS"` | the protocol status byte (4) of a `FCGI_END_REQUEST` record body has an unknown value, `arg1` holding the value |
| `"TOO_MANY_MSGS"` | the bucket collected too many unfinished stream messages |
| `"TOO_MANY_RECORDS"` | the bucket collected too many records inside one unfinished stream message of type `arg1` for a request ID `arg2` |

After an error is handled by `onError()`, the erroneous record is rejected and the bucket can continue to consume more records. However, some of these conditions may require actions:

- If `"DIRTY_BUCKET"` happened because you forgot to delete a request, delete it using `removeRequest()`.
- `"TOO_MANY_MSGS"` can be bypassed by increasing the `bucket.maxMsgs` constant.
- `"TOO_MANY_RECORDS"` can be bypassed by increasing the `bucket.maxNRecordsPerMsg` constant.

The return value of the `onError()` callback becomes the return value of `pushRecord()`.

If no errors are encountered or if `onError()` returns `null`, the result of `pushRecord()` is `null`.

---

#### bucket.pushManyRecords()

`bucket.pushManyRecords(records, onError = null) -> list of nulls or onError results`

Appends a list of `Record` objects to the inner state.

Basically, invokes `pushRecord()` in a loop for each record.

---

#### bucket.handleOne()

`bucket.handleOne(requestId, arg, cb) -> null`

Handles a request object with a request ID `requestId`.

No-op if request with such ID doesn't exists.

If the requests exists, the callback `cb()` is invoked with the following arguments: `cb(request, arg)`, where `request` is a map containing all collected messages for the request ID.

In addition to `recordType => message` pairs, several more properties are set to the request map which just proxy the properties of underlying messages.

Properties of a request map:

| Property / method | Description |
| --- | --- |
| `requestId` | request ID |
| *\<record type>* | *\<message object>* |
| ... | ... |
| `role` | (if `BeginRequestMsg` is present) FastCGI role |
| `keepConnectionP` | (if `BeginRequestMsg` is present) if true, keep connection open after responding to the request |
| `isAborted` | true if `AbortRequestMsg` is present |
| `appStatus` | (if `EndRequestMsg` is present) CGI exit code |
| `protoStatus` | (if `EndRequestMsg` is present) a constant from `fcgiCodec.protoStatus` |
| `params` | (if `ParamsMsg` is present) map of CGI params |
| `stdin` | (if `StdinMsg` is present) CGI stdin as a `RawData` |
| `stdinString` | (if `StdinMsg` is present) CGI stdin as a string |
| `stdout` | (if `StdoutMsg` is present) CGI stdout as a `RawData` |
| `stdoutString` | (if `StdoutMsg` is present) CGI stdout as a string |
| `stderr` | (if `StderrMsg` is present) CGI stderr as a `RawData` |
| `stderrString` | (if `StderrMsg` is present) CGI stderr as a string |
| `data` | (if `DataMsg` is present) data for `FCGI_FILTER` role as a `RawData` |
| `dataString` | (if `DataMsg` is present) data for `FCGI_FILTER` role as a string |
| `names` | (if `GetValuesMsg` is present) list of names of requested variables |
| `result` | (if `GetValuesResultMsg` is present) map of requested variables |
| `unknownType` | (if `UnknownTypeMsg` is present) unknown record type |

If some message is not present, the value of its additional property is `null`.

The callback should return `true`, if it's done with the request. The request will be deleted from the bucket.

Otherwise, the request will be kept in a bucket and the `handleOne()` method will attempt to handle it again on its next invokation. (You might want to do it if you expect more messages for the same request ID to arrive in the future).

---

#### bucket.handleAll()

`bucket.handleAll(arg, cb) -> null`

Handles all request objects.

Basically, invokes `handleOne()` in a loop for each request.

---

#### bucket.removeRequest()

`bucket.removeRequest(requestId) -> request map`

Deletes a request object from a bucket and returns it.

---


## NameValuePairs

`NameValuePairs` class decodes name-value pairs from `FCGI_GET_VALUES`, `FCGI_GET_VALUES_RESULT` and `FCGI_PARAMS` record types.

See the specification for the format.

The names and values are stored as MiniScript strings.

| Property / method | Description |
| --- | --- |
| `map` | map of name-value pairs |
| `make()` (class method) | returns a new `NameValuePairs` object |
| `pushData()` | appends a raw data chunk to an internal data collection |
| `names()` | returns all names |
| `getValue()` | returns a value by name |
| `setValue()` | sets a value by name |
| `deleteValue()` | deletes a value by name |
| `hasName()` | true if a name-value pair exists |
| `toRawData()` | returns encoded raw data |

#### NameValuePairs.make()

`NameValuePairs.make(rr = null) -> NameValuePairs`

(Class method) Returns a new `NameValuePairs` object.

If an optional list of data chunks is given, it will be parsed for the name-values.

---

#### nameValuePairs.pushData()

`nameValuePairs.pushData(r) -> null`

Appends a raw data chunk to an internal data collection.

The parsing starts immediately and decodes as many name-value pairs as available.

When there's not enough data for a whole pair, the parsing stops till the next call to `pushData()` brings more input.

---

#### nameValuePairs.names()

`nameValuePairs.names() -> list of names`

Returns all names.

---

#### nameValuePairs.getValue()

`nameValuePairs.getValue(name, default = null) -> value | default`

Returns a value by name.

If the pair doesn't exist, the `default` is returned.

---

#### nameValuePairs.setValue()

`nameValuePairs.setValue(name, value) -> null`

Sets a value by name.

---

#### nameValuePairs.deleteValue()

`nameValuePairs.deleteValue(name) -> null`

Deletes a value by name.

---

#### nameValuePairs.hasName()

`nameValuePairs.hasName(name) -> true | false`

Returns true if a name-value pair exists.

---

#### nameValuePairs.toRawData()

`nameValuePairs.toRawData() -> RawData`

Returns encoded raw data.

---


## Social art

Minnie the chinchilla by [Joe Strout](https://github.com/JoeStrout/).

Helmet "FAST" by [these guys](https://www.vecteezy.com/vector-art/7808449-skull-helmet-illustration-design-for-t-shirt-and-print).
