import "importUtil"
ensureImport "qa"

version = "0.1.1"

x80_00_00_00 = 128 * 2 ^ 24

bytesAlignment = 8

sentinel = []
sentinel.push function ; end function

proto = {}
proto.FCGI_VERSION_1 = 1
_proto = proto

recordType = {}
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
recordType.FCGI_MAXTYPE = 11
_recordType = recordType

role = {}
role.FCGI_RESPONDER = 1
role.FCGI_AUTHORIZER = 2
role.FCGI_FILTER = 3
_role = role

flag = {}
flag.FCGI_KEEP_CONN = 1
_flag = flag

protoStatus = {}
protoStatus.FCGI_REQUEST_COMPLETE = 0
protoStatus.FCGI_CANT_MPX_CONN = 1
protoStatus.FCGI_OVERLOADED = 2
protoStatus.FCGI_UNKNOWN_ROLE = 3
_protoStatus = protoStatus

errMsg = {}
errMsg.UNKNOWN_PROTO = "unknown FastCGI protocol: `{arg1}`"
errMsg.UNKNOWN_RECORD_TYPE = "unknown FastCGI record type: `{arg1}`"
errMsg.UNKNOWN_ROLE = "unknown FastCGI role: `{arg1}`"
errMsg.UNKNOWN_PROTO_STATUS = "unknown FastCGI protocol status: `{arg1}`"
errMsg.TOO_MANY_MSGS = "too many unfinished messages"
errMsg.TOO_MANY_RECORDS = "too many records in a message, record type = `{arg1}`, request ID = `{arg2}`"
errMsg.BODY_TOO_SHORT = "expected {arg1} bytes of FastCGI record body, got {arg2} bytes"
errMsg.DIRTY_BUCKET = "multiple messages of type `{arg1}` for request `{arg2}`"
_errMsg = errMsg





//                                      +---------+
//                                      |  utils  |
//                                      +---------+


// from /sys/startup.ms
refIndexOf = function(l, item)
	i = 0; llen = l.len
	while i < llen
		if refEquals(l[i], @item) then return i
		i += 1
	end while
	return null
end function

// from /sys/lib/mapUtil.ms
mapGet = function(m, key, defaultValue = null)
	while m
		if m.hasIndex(@key) then return m[@key]
		if not m.hasIndex("__isa") then break
		m = m.__isa
	end while
	return @defaultValue
end function

// mapSetDefault: Returns  `m[key]`, sets `m[key]` to `defaultValue` if doesn't exist (like Python's dict.setDefault).
mapSetDefault = function(m, key, defaultValue)
	value = mapGet(m, @key, sentinel)
	if @value == sentinel then m[@key] = @defaultValue
	return m[@key]
end function

// str: Similar to vanilla `str`, but invokes a custom `._str` method if present.
str = function(x, depth = null, _nested = null)
	if depth == null or depth == 1/0 or depth < 0 then depth = 3
	if @x == null then
		if _nested then return "null" else return ""
	end if
	if @x isa string then
		if _nested then return intrinsics.str([x])[1:-1] else return x
	end if
	if @x isa list then
		if x.len == 0 then return "[]"
		if depth == 0 then return "[…(" + x.len + ")]"
		subs = []
		for elem in x
			subs.push str(@elem, depth - 1, true)
		end for
		return "[" + subs.join(", ") + "]"
	end if
	if @x isa map then
		if mapGet(x, "_str") then return x._str(depth)
		if x.hasIndex("_name") then return x._name
		if mapGet(x, "_name") then
			if mapGet(x, "_repr") then return x._name + "(" + x._repr(depth - 1) + ")"
			if mapGet(x, "_id") then return x._name + "(" + x._id + ")"
		end if
		if len(x) == 0 then return "{}"
		if depth == 0 then return "{…(" + x.len + ")}"
		subs = []
		for kv in x
			subs.push str(@kv.key, depth - 1, true) + ": " + str(@kv.value, depth - 1, true)
		end for
		return "{" + subs.join(", ") + "}"
	end if
	return intrinsics.str(@x)
end function

// rawDataCmp: Compares two RawData objects, returns `-1` if `r1<r2`, `0` if `r1==r2` and `-1` if `r1>r2`.
rawDataCmp = function(r1, r2)
	i = 0
	while true
		if i == r1.len and i == r2.len then return 0
		if i == r1.len then return -1
		if i == r2.len then return 1
		byte1 = r1.byte(i)
		byte2 = r2.byte(i)
		if byte1 < byte2 then return -1
		if byte1 > byte2 then return 1
		i += 1
	end while
end function

// stringToRawData: Returns a new RawData object containing `s`.
stringToRawData = function(s)
	r = new RawData
	r.resize s.len * 4
	r.resize r.setUtf8(0, s)
	return r
end function

// rawDataToString: Returns a string containing RawData's content.
rawDataToString = function(r)
	if r.len == 0 then return ""
	return r.utf8
end function





//                                      +-----------------------+
//                                      |  RawData collections  |
//                                      +-----------------------+


// ???
RawDataCollection = {}
RawDataCollection._name = "fcgiCodec:RawDataCollection"
RawDataCollection.init = function(rr = null)
	if rr == null then rr = []
	if not rr isa list then rr = [rr]
	self.list = []
	self.offset = 0
	self.len = 0
	for r in rr
		self.push r
	end for
	return self
end function

RawDataCollection.make = function(rr = null)
	return (new self).init(@rr)
end function

// ???
RawDataCollection.totalBytes = function
	t = 0
	for r in self.list
		t += r.len
	end for
	return t
end function

// ???
RawDataCollection.push = function(r, keepLengthP = false)
	if @r isa string then r = stringToRawData(r)
	if not (@r isa RawData or @r isa RawDataCollection) then qa.abort "expected RawData or RawDataCollection, got `" + str(@r) + "`"
	self.list.push r
	if not keepLengthP then self.len += r.len
end function

// ???
RawDataCollection.tailBytes = function
	return self.totalBytes - self.offset - self.len
end function

// ???
RawDataCollection.advance = function(nBytes)
	if self.offset + nBytes < 0 then nBytes = -self.offset
	self.offset += nBytes
	self.len -= nBytes
	if self.len < 0 then self.len = 0
	l = []
	for r in self.list
		if self.offset >= r.len then
			self.offset -= r.len
			continue
		end if
		l.push r
	end for
	self.list = l
end function

// ???
RawDataCollection.grow = function(nBytes)
	self.len += nBytes
	if self.len < 0 then self.len = 0
	maxLen = self.totalBytes - self.offset
	if self.len > maxLen then self.len = maxLen
end function

// ???
RawDataCollection.toRawData = function(offset = 0, nBytes = null, _acc = null, _accIndex = null)
	if offset == null or offset < 0 then offset = 0
	if nBytes == null or offset + nBytes > self.len then nBytes = self.len - offset
	nBytes = floor(nBytes)
	if nBytes <= 0 then return new RawData
	offset += self.offset
	if _acc == null then
		_acc = new RawData
		_acc.resize nBytes
		_accIndex = 0
	end if
	for r in self.list
		if offset >= r.len then
			offset -= r.len
			continue
		end if
		if offset + nBytes <= r.len then
			self._slurpRawData r, offset, nBytes, _acc, _accIndex
			break
		else
			nToSlurp = r.len - offset
			self._slurpRawData r, offset, nToSlurp, _acc, _accIndex
			offset = 0
			nBytes -= nToSlurp
			_accIndex += nToSlurp
		end if
	end for
	return _acc
end function

// ???
RawDataCollection._slurpRawData = function(r, offset, nBytes, _acc, _accIndex)
	if r isa RawDataCollection then r.toRawData offset, nBytes, _acc, _accIndex
	if r isa RawData then
		for i in range(0, nBytes - 1, 1)
			_acc.setByte _accIndex + i, r.byte(offset + i)
		end for
	end if
end function

// ???
RawDataCollection.toRawDataList = function(offset = 0, nBytes = null, _rdl = null)
	if offset == null or offset < 0 then offset = 0
	if nBytes == null or offset + nBytes > self.len then nBytes = self.len - offset
	nBytes = floor(nBytes)
	if nBytes <= 0 then return new RawData
	offset += self.offset
	if _rdl == null then _rdl = []
	for r in self.list
		if offset >= r.len then
			offset -= r.len
			continue
		end if
		if offset + nBytes <= r.len then
			self._slurpRawDataList r, offset, nBytes, _rdl
			break
		else
			nToSlurp = r.len - offset
			self._slurpRawDataList r, offset, nToSlurp, _rdl
			offset = 0
			nBytes -= nToSlurp
		end if
	end for
	return _rdl
end function

// ???
RawDataCollection._slurpRawDataList = function(r, offset, nBytes, _rdl)
	if r isa RawDataCollection then r.toRawDataList offset, nBytes, _rdl
	if r isa RawData then
		if offset == 0 and nBytes == r.len then
			_rdl.push r
			return
		end if
		acc = new RawData
		acc.resize nBytes
		accIndex = 0
		for i in range(0, nBytes - 1, 1)
			acc.setByte accIndex + i, r.byte(offset + i)
		end for
		_rdl.push acc
	end if
end function

// ???
RawDataCollection.copy = function
	r = self + {}
	r.list = r.list[:]
	return r
end function

// ???
RawDataCollection.indexOf = function(x, after = 0)
	if x isa string then x = stringToRawData(x)
	if after == null then after = 0
	if after + x.len > self.len then return null
	for i in range(after, self.len - x.len, 1)
		r = self.toRawData(i, x.len)
		if rawDataCmp(x, r) == 0 then return i
	end for
	return null
end function





//                                      +------------------+
//                                      |  NameValuePairs  |
//                                      +------------------+


// ???
NameValuePairs = {}
NameValuePairs._name = "fcgiCodec:NameValuePairs"
NameValuePairs.isSorted = false
NameValuePairs.init = function(rr = null)
	if rr == null then rr = []
	if not rr isa list then rr = [rr]
	self.map = {}
	self.rdcol = RawDataCollection.make
	self.isComplete = true
	self.state = "BEGIN"
	self.acc = {}
	for r in rr
		self.pushData r
	end for
	return self
end function

NameValuePairs.make = function(rr = null)
	return (new self).init(@rr)
end function

// ???
NameValuePairs.encodeLength = function(length)
	if length < 128 then
		r = new RawData
		r.resize 1
		r.setByte 0, length
		return r
	end if
	if length >= x80_00_00_00 then qa.abort "length too big: " + str(length)
	r = new RawData
	r.resize 4
	r.littleEndian = false
	r.setUint 0, length + x80_00_00_00
	return r
end function

// ???
NameValuePairs.decodeLength = function(r)
	if r.len == 0 then return null
	first = r.byte
	if first < 128 then return first
	if r.len < 4 then return null
	r.littleEndian = false
	return r.uint - x80_00_00_00
end function

// ???
NameValuePairs.pushData = function(r)
	self.rdcol.push r
	while true
		if self.state == "BEGIN" then
			length = self._eatLength
			if length == null then return
			self.isComplete = false
			self.acc.nameLength = length
			self.state = "VALUE_LENGTH"
			continue
		else if self.state == "VALUE_LENGTH" then
			length = self._eatLength
			if length == null then return
			self.acc.valueLength = length
			self.state = "NAME_DATA"
			continue
		else if self.state == "NAME_DATA" then
			r = self._eatData(self.acc.nameLength)
			if r == null then return
			self.acc.nextName = rawDataToString(r)
			self.state = "VALUE_DATA"
			continue
		else if self.state == "VALUE_DATA" then
			r = self._eatData(self.acc.valueLength)
			if r == null then return
			self.map[self.acc.nextName] = rawDataToString(r)
			self.isComplete = true
			self.acc = {}
			self.state = "BEGIN"
			continue
		else
			qa.abort "unknown state: `" + str(self.state) + "`"
		end if
	end while
end function

// ???
NameValuePairs.names = function
	names = self.map.indexes
	if self.isSorted then names.sort
	return names
end function

// ???
NameValuePairs.getValue = function(name, default = null)
	return mapGet(self.map, name, @default)
end function

// ???
NameValuePairs.setValue = function(name, value)
	if @name isa RawData then name = rawDataToString(name)
	if not @name isa string then name = str(@name)
	if @value isa RawData then value = rawDataToString(value)
	if not @value isa string then value = str(@value)
	self.map[name] = value
end function

// ???
NameValuePairs.deleteValue = function(name)
	self.map.remove @name
end function

// ???
NameValuePairs.hasName = function(name)
	return self.map.hasIndex(name)
end function

// ???
NameValuePairs.toRawDataCollection = function
	rdcol = RawDataCollection.make
	for name in self.names
		value = self.map[name]
		rdcol.push self.encodeLength(name.len)
		rdcol.push self.encodeLength(value.len)
		rdcol.push name
		rdcol.push value
	end for
	return rdcol
end function

// ???
NameValuePairs.toRawData = function
	return self.toRawDataCollection.toRawData
end function

// ???
NameValuePairs.toRawDataString = function
	return rawDataToString(self.toRawDataCollection.toRawData)
end function

// ???
NameValuePairs.toRawDataList = function
	return self.toRawDataCollection.toRawDataList
end function

NameValuePairs._eatLength = function
	r1 = self.rdcol.toRawData(0, 1)
	length = self.decodeLength(r1)
	if length != null then
		self.rdcol.advance 1
		return length
	end if
	r4 = self.rdcol.toRawData(0, 4)
	length = self.decodeLength(r4)
	if length != null then
		self.rdcol.advance 4
		return length
	end if
	return null
end function

NameValuePairs._eatData = function(length)
	if self.rdcol.len < length then return null
	r = self.rdcol.toRawData(0, length)
	self.rdcol.advance length
	return r
end function





//                                      +----------+
//                                      |  Record  |
//                                      +----------+


// ???
Record = {}
Record._name = "fcgiCodec:Record"
Record.init = function(recordType, requestId = 0, body)
	if _recordType.indexOf(recordType) == null then qa.abort "unknown FastCGI record type: `" + str(recordType) + "`"
	if requestId == null then requestId = 0
	self.recordType = recordType
	self.requestId = requestId
	self.rdcol = RawDataCollection.make(body)
	return self
end function

Record.make = function(recordType, requestId = 0, body)
	return (new self).init(@recordType, @requestId, @body)
end function

// ???
Record.paddingLength = function(dataLength)
	l = bytesAlignment - dataLength % bytesAlignment
	if l == bytesAlignment then l = 0
	return l
end function

// ???
Record.isStreamType = function(recordType)
	return _recordType.FCGI_PARAMS <= recordType <= _recordType.FCGI_DATA
end function

// ???
Record.body = function
	return self.rdcol.toRawData
end function

// ???
Record.toRawDataCollection = function
	length = self.rdcol.len
	padding = self.paddingLength(length)
	header = new RawData
	header.resize 8
	header.littleEndian = false
	header.setByte 0, _proto.FCGI_VERSION_1
	header.setByte 1, self.recordType
	header.setUshort 2, self.requestId
	header.setUshort 4, length
	header.setByte 6, padding
	header.setByte 7, 0
	rdcol = RawDataCollection.make
	rdcol.push header
	rdcol.push self.rdcol
	if padding > 0 then
		p = new RawData
		p.resize padding
		for i in range(0, padding - 1, 1)
			p.setByte i, 0
		end for
		rdcol.push p
	end if
	return rdcol
end function

// ???
Record.toRawData = function
	return self.toRawDataCollection.toRawData
end function

// ???
Record.toRawDataList = function
	return self.toRawDataCollection.toRawDataList
end function





//                                      +----------------+
//                                      |  *Msg classes  |
//                                      +----------------+
//
//  ·-------·
//  |  Msg  |
//  ·-------·
//      .recordType
//      .requestId
//      .toRecords
//
//      |        ·--------------------·
//      +------> | BeginRequestMsg    |
//      |        ·--------------------·
//      |                  .make(requestId, role, keepConnectionP)
//      |
//      |        ·--------------------·
//      +------> | AbortRequestMsg    |
//      |        ·--------------------·
//      |                  .make(requestId)
//      |
//      |        ·--------------------·
//      +------> | EndRequestMsg      |
//      |        ·--------------------·
//      |                  .make(requestId, appStatus, protoStatus)
//      |
//      |        ·--------------------·
//      +------> | ParamsMsg          |
//      |        ·--------------------·
//      |                  .make(requestId, paramsMap)
//      |
//      |        ·--------------------·
//      +------> | GetValuesMsg       |
//      |        ·--------------------·
//      |                  .make(names)
//      |
//      |        ·--------------------·
//      +------> | GetValuesResultMsg |
//      |        ·--------------------·
//      |                  .make(valuesMap)
//      |
//      |        ·--------------------·
//      +------> | UnknownTypeMsg     |
//      |        ·--------------------·
//      |                  .make(unknownType)
//      |
//      |        ·--------------------·
//      +------> | BlobMsg            |
//               ·--------------------·
//                         .make(requestId, data)
//       
//                         |
//                         |           ·-----------·
//                         +---------> | StdinMsg  |
//                         |           ·-----------·
//                         |           ·-----------·
//                         +---------> | StdoutMsg |
//                         |           ·-----------·
//                         |           ·-----------·
//                         +---------> | StderrMsg |
//                         |           ·-----------·
//                         |           ·-----------·
//                         +---------> | DataMsg   |
//                                     ·-----------·


// ???
Msg = {}
Msg._name = "fcgiCodec:Msg"
Msg.recordType = null
Msg.requestId = 0
Msg.classByRecordType = {}
Msg.init = function
	return self
end function

Msg.setRecordType = function(recordType)
	self.recordType = recordType
	self.classByRecordType[recordType] = self
end function

Msg.getClass = function(recordType)
	return Msg.classByRecordType[recordType]
end function

// ???
Msg.collection = function
	qa.abort "implement me!"
end function

// ???
Msg.toRecords = function(chunkLength = null)
	if chunkLength == null or chunkLength < 1 then chunkLength = 1/0
	rdcol = self.collection
	if not Record.isStreamType(self.recordType) then return [Record.make(self.recordType, self.requestId, rdcol)]
	offset = 0
	records = []
	while true
		r = rdcol.toRawDataList(offset, chunkLength)
		records.push Record.make(self.recordType, self.requestId, r)
		offset += chunkLength
		if r.len == 0 then break
	end while
	return records
end function


// ???
BeginRequestMsg = new Msg
BeginRequestMsg._name = "fcgiCodec:BeginRequestMsg"
BeginRequestMsg.setRecordType _recordType.FCGI_BEGIN_REQUEST
BeginRequestMsg.init = function(requestId, role, keepConnectionP)
	super.init
	if _role.indexOf(role) == null then qa.abort "unknown FastCGI role: `" + str(role) + "`"
	self.requestId = requestId
	self.role = role
	self.keepConnectionP = keepConnectionP
	return self
end function

BeginRequestMsg.make = function(requestId, role, keepConnectionP)
	return (new self).init(@requestId, @role, @keepConnectionP)
end function

BeginRequestMsg.collection = function
	r = new RawData
	r.resize 8
	r.littleEndian = false
	r.setUshort 0, self.role
	r.setByte 2, self.keepConnectionP
	r.setByte 3, 0
	r.setByte 4, 0
	r.setByte 5, 0
	r.setByte 6, 0
	r.setByte 7, 0
	return RawDataCollection.make(r)
end function


// ???
AbortRequestMsg = new Msg
AbortRequestMsg._name = "fcgiCodec:AbortRequestMsg"
AbortRequestMsg.setRecordType _recordType.FCGI_ABORT_REQUEST
AbortRequestMsg.init = function(requestId)
	super.init
	self.requestId = requestId
	return self
end function

AbortRequestMsg.make = function(requestId)
	return (new self).init(@requestId)
end function

AbortRequestMsg.collection = function
	return RawDataCollection.make
end function


// ???
EndRequestMsg = new Msg
EndRequestMsg._name = "fcgiCodec:EndRequestMsg"
EndRequestMsg.setRecordType _recordType.FCGI_END_REQUEST
EndRequestMsg.init = function(requestId, appStatus, protoStatus)
	super.init
	if _protoStatus.indexOf(protoStatus) == null then qa.abort "unknown FastCGI protocol status: `" + str(protoStatus) + "`"
	self.requestId = requestId
	self.appStatus = appStatus
	self.protoStatus = protoStatus
	return self
end function

EndRequestMsg.make = function(requestId, appStatus, protoStatus)
	return (new self).init(@requestId, @appStatus, @protoStatus)
end function

EndRequestMsg.collection = function
	r = new RawData
	r.resize 8
	r.littleEndian = false
	r.setUint 0, self.appStatus
	r.setByte 4, self.protoStatus
	r.setByte 5, 0
	r.setByte 6, 0
	r.setByte 7, 0
	return RawDataCollection.make(r)
end function


// ???
ParamsMsg = new Msg
ParamsMsg._name = "fcgiCodec:ParamsMsg"
ParamsMsg.setRecordType _recordType.FCGI_PARAMS
ParamsMsg.init = function(requestId, paramsMap)
	super.init
	self.requestId = requestId
	self.pairs = NameValuePairs.make
	for kv in paramsMap
		self.pairs.setValue @kv.key, @kv.value
	end for
	return self
end function

ParamsMsg.make = function(requestId, paramsMap)
	return (new self).init(@requestId, @paramsMap)
end function

ParamsMsg.collection = function
	return self.pairs.toRawDataCollection
end function

ParamsMsg.paramsMap = function
	return self.pairs.map + {}
end function


// ???
BlobMsg = new Msg
BlobMsg._name = "fcgiCodec:BlobMsg"
BlobMsg.init = function(requestId, data)
	super.init
	self.requestId = requestId
	self.rdcol = RawDataCollection.make(data)
	return self
end function

BlobMsg.make = function(requestId, data)
	return (new self).init(@requestId, @data)
end function

BlobMsg.collection = function
	return self.rdcol
end function

// ???
BlobMsg.data = function
	return self.rdcol.toRawData
end function


// ???
StdinMsg = new BlobMsg
StdinMsg._name = "fcgiCodec:StdinMsg"
StdinMsg.setRecordType _recordType.FCGI_STDIN


// ???
StdoutMsg = new BlobMsg
StdoutMsg._name = "fcgiCodec:StdoutMsg"
StdoutMsg.setRecordType _recordType.FCGI_STDOUT


// ???
StderrMsg = new BlobMsg
StderrMsg._name = "fcgiCodec:StderrMsg"
StderrMsg.setRecordType _recordType.FCGI_STDERR


// ???
DataMsg = new BlobMsg
DataMsg._name = "fcgiCodec:DataMsg"
DataMsg.setRecordType _recordType.FCGI_DATA


// ???
GetValuesMsg = new Msg
GetValuesMsg._name = "fcgiCodec:GetValuesMsg"
GetValuesMsg.setRecordType _recordType.FCGI_GET_VALUES
GetValuesMsg.init = function(names)
	super.init
	self.pairs = NameValuePairs.make
	for name in names
		self.pairs.setValue @name, ""
	end for
	return self
end function

GetValuesMsg.make = function(names)
	return (new self).init(@names)
end function

GetValuesMsg.collection = function
	return self.pairs.toRawDataCollection
end function

// ???
GetValuesMsg.names = function
	return self.pairs.names
end function

// ???
GetValuesMsg.nameSet = function
	m = {}
	for name in self.pairs.names
		m.push name
	end for
	return m
end function


// ???
GetValuesResultMsg = new Msg
GetValuesResultMsg._name = "fcgiCodec:GetValuesResultMsg"
GetValuesResultMsg.setRecordType _recordType.FCGI_GET_VALUES_RESULT
GetValuesResultMsg.init = function(valuesMap)
	super.init
	self.pairs = NameValuePairs.make
	for kv in valuesMap
		self.pairs.setValue @kv.key, @kv.value
	end for
	return self
end function

GetValuesResultMsg.make = function(valuesMap)
	return (new self).init(@valuesMap)
end function

GetValuesResultMsg.collection = function
	return self.pairs.toRawDataCollection
end function

GetValuesResultMsg.valuesMap = function
	return self.pairs.map + {}
end function


// ???
UnknownTypeMsg = new Msg
UnknownTypeMsg._name = "fcgiCodec:UnknownTypeMsg"
UnknownTypeMsg.setRecordType _recordType.FCGI_UNKNOWN_TYPE
UnknownTypeMsg.init = function(unknownType)
	super.init
	self.unknownType = unknownType
	return self
end function

UnknownTypeMsg.make = function(unknownType)
	return (new self).init(@unknownType)
end function

UnknownTypeMsg.collection = function
	r = new RawData
	r.resize 8
	r.setByte 0, self.unknownType
	r.setByte 1, 0
	r.setByte 2, 0
	r.setByte 3, 0
	r.setByte 4, 0
	r.setByte 5, 0
	r.setByte 6, 0
	r.setByte 7, 0
	return RawDataCollection.make(r)
end function





//                                      +-----------------+
//                                      |  RecordDecoder  |
//                                      +-----------------+

RecordDecoder = {}
RecordDecoder._name = "fcgiCodec:RecordDecoder"
RecordDecoder.init = function
	self.rdcol = RawDataCollection.make
	self.state = null
	self.acc = {}
	self.records = []
	return self
end function

RecordDecoder.make = function
	return (new self).init
end function

// ???
RecordDecoder.pushData = function(r, onError = null)
	if @onError != null then
		
		_err = function(errCode, arg1 = null)
			return onError(errCode, arg1)
		end function
		
	else
		
		_err = function(errCode, arg1 = null)
			msg = _errMsg[errCode]
			msg = msg.replace("{arg1}", str(@arg1))
			qa.abort msg
		end function
		
	end if
	self.rdcol.push r
	if self.state == null then self.state = "BEGIN"
	while true
		if self.state == "BEGIN" then
			header = self._eatHeader
			if header == null then return
			header.littleEndian = false
			proto = header.byte(0)
			if _proto.indexOf(proto) == null then return _err("UNKNOWN_PROTO", proto)
			recordType = header.byte(1)
			if _recordType.indexOf(recordType) == null then return _err("UNKNOWN_RECORD_TYPE", recordType)
			self.acc = {}
			self.acc.recordType = recordType
			self.acc.requestId = header.ushort(2)
			self.acc.dataLength = header.ushort(4)
			self.acc.paddingLength = header.byte(6)
			self.state = "DATA"
			continue
		else if self.state == "DATA" then
			data = self._eatData(self.acc.dataLength)
			if data == null then return
			self.records.push Record.make(self.acc.recordType, self.acc.requestId, data)
			self.state = "PADDING"
			continue
		else if self.state == "PADDING" then
			padding = self._eatData(self.acc.paddingLength)
			if padding == null then return
			self.state = "BEGIN"
			continue
		else
			qa.abort "unknown state: `" + str(self.state) + "`"
		end if
	end while
end function

// ???
RecordDecoder.getRecord = function
	return self.records.pull
end function

// ???
RecordDecoder.getAllRecords = function
	records = []
	while true
		record = self.getRecord
		if record == null then break
		records.push record
	end while
	return records
end function

// ???
RecordDecoder._eatHeader = function
	header = self.rdcol.toRawData(0, 8)
	if header.len < 8 then return null
	self.rdcol.advance 8
	return header
end function

// ???
RecordDecoder._eatData = function(length)
	data = self.rdcol.copy
	data.len = 0
	data.grow length
	if data.len < length then return null
	self.rdcol.advance length
	return data
end function





//                                      +----------+
//                                      |  Bucket  |
//                                      +----------+

Bucket = {}
Bucket._name = "fcgiCodec:Bucket"
Bucket.isSorted = false
Bucket.maxMsgs = 100
Bucket.maxNRecordsPerMsg = 100
Bucket.init = function
	self.requests = {}
	self.acc = {}
	return self
end function

Bucket.make = function
	return (new self).init
end function

// ???
Bucket.nRequests = function
	return self.requests.len
end function

// ???
Bucket.requestIds = function
	ids = self.requests.indexes
	if self.isSorted then ids.sort
	return ids
end function

// ???
Bucket.pushRecord = function(record, onError = null)
	if not record isa Record then qa.abort "expected Record, got `" + str(record) + "`"
	if @onError != null then
		
		_err = function(errCode, arg1 = null, arg2 = null)
			return onError(errCode, arg1, arg2)
		end function
		
	else
		
		_err = function(errCode, arg1 = null, arg2 = null)
			msg = _errMsg[errCode]
			msg = msg.replace("{arg1}", str(@arg1))
			msg = msg.replace("{arg2}", str(@arg2))
			qa.abort msg
		end function
		
	end if
	request = mapGet(self.requests, record.requestId)
	if request != null and request.hasIndex(record.recordType) then return _err("DIRTY_BUCKET", record.recordType, record.requestId)
	msg = null
	if record.recordType == recordType.FCGI_BEGIN_REQUEST then
		if record.rdcol.len < 8 then return _err("BODY_TOO_SHORT", 8, record.rdcol.len)
		r = record.rdcol.toRawData(0, 2)
		r.littleEndian = false
		role = r.ushort
		if _role.indexOf(role) == null then return _err("UNKNOWN_ROLE", role)
		r = record.rdcol.toRawData(2, 1)
		flags = r.byte
		keepConnectionP = bitAnd(flags, flag.FCGI_KEEP_CONN)
		msg = BeginRequestMsg.make(record.requestId, role, keepConnectionP)
	else if record.recordType == recordType.FCGI_ABORT_REQUEST then
		msg = AbortRequestMsg.make(record.requestId)
	else if record.recordType == recordType.FCGI_END_REQUEST then
		if record.rdcol.len < 8 then return _err("BODY_TOO_SHORT", 8, record.rdcol.len)
		r = record.rdcol.toRawData(0, 4)
		r.littleEndian = false
		appStatus = r.uint
		r = record.rdcol.toRawData(4, 1)
		protoStatus = r.byte
		if _protoStatus.indexOf(protoStatus) == null then return _err("UNKNOWN_PROTO_STATUS", protoStatus)
		msg = EndRequestMsg.make(record.requestId, appStatus, protoStatus)
	else if record.recordType == recordType.FCGI_GET_VALUES then
		pairs = NameValuePairs.make(record.rdcol)
		msg = GetValuesMsg.make(pairs.names)
	else if record.recordType == recordType.FCGI_GET_VALUES_RESULT then
		pairs = NameValuePairs.make(record.rdcol)
		msg = GetValuesResultMsg.make(pairs.map)
	else if record.recordType == recordType.FCGI_UNKNOWN_TYPE then
		if record.rdcol.len < 8 then return _err("BODY_TOO_SHORT", 8, record.rdcol.len)
		r = record.rdcol.toRawData(0, 1)
		unknownType = r.byte(0)
		msg = UnknownTypeMsg.make(unknownType)
	end if
	if msg != null then
		request = mapSetDefault(self.requests, record.requestId, self._makeRequestMap(record.requestId))
		self._pushMessage request, msg
		return null
	end if
	accKey = [record.recordType, record.requestId]
	if record.rdcol.len == 0 then
		records = mapGet(self.acc, accKey, [])
		rdcol = RawDataCollection.make
		for r in records
			rdcol.push r.rdcol
		end for
		if record.recordType == recordType.FCGI_PARAMS then
			pairs = NameValuePairs.make(rdcol)
			msg = ParamsMsg.make(record.requestId, pairs.map)
		else
			msg = Msg.getClass(record.recordType).make(record.requestId, rdcol)
		end if
		self.acc.remove accKey
		request = mapSetDefault(self.requests, record.requestId, self._makeRequestMap(record.requestId))
		self._pushMessage request, msg
		return null
	end if
	if not self.acc.hasIndex(accKey) then
		self.acc[accKey] = []
		if self.acc.len > self.maxMsgs then return _err("TOO_MANY_MSGS")
	end if
	self.acc[accKey].push record
	if self.acc[accKey].len > self.maxNRecordsPerMsg then return _err("TOO_MANY_RECORDS", record.recordType, record.requestId)
end function

// ???
Bucket.pushManyRecords = function(records, onError = null)
	rets = []
	for record in records
		rets.push self.pushRecord(record, @onError)
	end for
	return rets
end function

// ???
Bucket.handleOne = function(requestId, arg, cb)
	rawDataToString = @outer.rawDataToString
	request = mapGet(self.requests, requestId)
	if request == null then return
	removeP = cb(request, @arg)
	if removeP then self.requests.remove requestId
end function

// ???
Bucket.handleAll = function(arg, cb)
	for requestId in self.requestIds
		self.handleOne requestId, @arg, @cb
	end for
end function

// ???
Bucket.removeRequest = function(requestId)
	request = mapGet(self.requests, requestId)
	self.requests.remove requestId
	return request
end function

Bucket._makeRequestMap = function(requestId)
	return {
		"requestId":        requestId,
		"role":             null,
		"keepConnectionP":  null,
		"isAborted":        null,
		"appStatus":        null,
		"protoStatus":      null,
		"params":           null,
		"paramsPairs":      null,
		"stdinCollection":  null,
		"stdin":            null,
		"stdinString":      null,
		"stdoutCollection": null,
		"stdout":           null,
		"stdoutString":     null,
		"stderrCollection": null,
		"stderr":           null,
		"stderrString":     null,
		"dataCollection":   null,
		"data":             null,
		"dataString":       null,
		"names":            null,
		"result":           null,
		"unknownType":      null,
	}
end function

Bucket._pushMessage = function(request, msg)
	rawDataToString = @outer.rawDataToString
	request[msg.recordType] = msg
	if msg.recordType == recordType.FCGI_BEGIN_REQUEST then
		request.role = msg.role
		request.keepConnectionP = msg.keepConnectionP
	else if msg.recordType == recordType.FCGI_ABORT_REQUEST then
		request.isAborted = true
	else if msg.recordType == recordType.FCGI_END_REQUEST then
		request.appStatus = msg.appStatus
		request.protoStatus = msg.protoStatus
	else if msg.recordType == recordType.FCGI_PARAMS then
		request.params = msg.paramsMap
		request.paramsPairs = msg.pairs
	else if msg.recordType == recordType.FCGI_STDIN then
		request.stdinCollection = msg.rdcol
		request.stdin = function ; return request.stdinCollection.toRawData ; end function
		request.stdinString = function ; return rawDataToString(request.stdinCollection.toRawData) ; end function
	else if msg.recordType == recordType.FCGI_STDOUT then
		request.stdoutCollection = msg.rdcol
		request.stdout = function ; return request.stdoutCollection.toRawData ; end function
		request.stdoutString = function ; return rawDataToString(request.stdoutCollection.toRawData) ; end function
	else if msg.recordType == recordType.FCGI_STDERR then
		request.stderrCollection = msg.rdcol
		request.stderr = function ; return request.stderrCollection.toRawData ; end function
		request.stderrString = function ; return rawDataToString(request.stderrCollection.toRawData) ; end function
	else if msg.recordType == recordType.FCGI_DATA then
		request.dataCollection = msg.rdcol
		request.data = function ; return request.dataCollection.toRawData ; end function
		request.dataString = function ; return rawDataToString(request.dataCollection.toRawData) ; end function
	else if msg.recordType == recordType.FCGI_GET_VALUES then
		request.names = msg.names
		request.nameSet = msg.nameSet
	else if msg.recordType == recordType.FCGI_GET_VALUES_RESULT then
		request.result = msg.valuesMap
		request.resultPairs = msg.pairs
	else if msg.recordType == recordType.FCGI_UNKNOWN_TYPE then
		request.unknownType = msg.unknownType
	end if
end function
