ensureImport "qa"
ensureImport "fcgiCodec"

globals.str = @fcgiCodec.str
fcgiCodec.NameValuePairs.isSorted = true
fcgiCodec.Bucket.isSorted = true




// Tests for utils

testRefIndexOf = function
	a = {}
	qa.assertEqual fcgiCodec.refIndexOf([], a), null
	qa.assertEqual fcgiCodec.refIndexOf([a], a), 0
	qa.assertEqual fcgiCodec.refIndexOf([{}, {}, a], a), 2
	qa.assertEqual fcgiCodec.refIndexOf([{}, {}], a), null
end function

testMapGet = function
	qa.assertEqual fcgiCodec.mapGet({}, "foo"), null
	qa.assertEqual fcgiCodec.mapGet({}, "foo", 42), 42
	qa.assertEqual fcgiCodec.mapGet({"foo": 420}, "foo", 42), 420
	qa.assertEqual fcgiCodec.mapGet({"__isa": {"foo": 420}}, "foo", 42), 420
	qa.assertEqual fcgiCodec.mapGet({"__isa": {"__isa": {"foo": 420}}}, "foo", 42), 420
end function

testMapSetDefault = function
	m = {}
	x = fcgiCodec.mapSetDefault(m, "foo", "bar")
	qa.assertEqual x, "bar"
	qa.assertEqual m, {"foo": "bar"}
	x = fcgiCodec.mapSetDefault(m, "foo", "baz")
	qa.assertEqual x, "bar"
	qa.assertEqual m, {"foo": "bar"}
end function

testStr = function
	str = @fcgiCodec.str
	f = function(a, b) ; end function
	
	qa.assertEqual str(null), ""
	qa.assertEqual str(42), "42"
	qa.assertEqual str("foo"), "foo"
	qa.assertEqual str(@f), "FUNCTION(a, b)"
	
	qa.assertEqual str([]), "[]"
	qa.assertEqual str([null, 42, "foo", @f]), "[null, 42, ""foo"", FUNCTION(a, b)]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]]), "[42, [43, [44, […(2)]]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 2), "[42, [43, […(2)]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 0), "[…(2)]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], -1), "[42, [43, [44, […(2)]]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 1/0), "[42, [43, [44, […(2)]]]]"
	qa.assertEqual str([42, [43, [44, [45, [46, null]]]]], 10), "[42, [43, [44, [45, [46, null]]]]]"
	
	qa.assertEqual str({}), "{}"
	qa.assertEqual str({null: "foo"}), "{null: ""foo""}"
	qa.assertEqual str({@f: @f}), "{FUNCTION(a, b): FUNCTION(a, b)}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}), "{42: {43: {44: {…(1)}}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 2), "{42: {43: {…(1)}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 0), "{…(1)}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, -1), "{42: {43: {44: {…(1)}}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 1/0), "{42: {43: {44: {…(1)}}}}"
	qa.assertEqual str({42: {43: {44: {45: {46: null}}}}}, 10), "{42: {43: {44: {45: {46: null}}}}}"
	
	m = {}
	m._str = function(depth) ; return "foo" ; end function
	qa.assertEqual str(m), "foo"
	qa.assertEqual str(new m), "foo"
	qa.assertEqual str(new (new m)), "foo"
	
	A = {"_name": "A"}
	qa.assertEqual str(A), "A"
	qa.assertEqual str(new A), "{""__isa"": A}"
	qa.assertEqual str(new (new A)), "{""__isa"": {""__isa"": A}}"
	
	A = {"_name": "A"}
	A._repr = function(depth) ; return "foo" ; end function
	qa.assertEqual str(A), "A"
	qa.assertEqual str(new A), "A(foo)"
	qa.assertEqual str(new (new A)), "A(foo)"
	
	A = {"_name": "A"}
	A._id = "foo"
	qa.assertEqual str(A), "A"
	qa.assertEqual str(new A), "A(foo)"
	qa.assertEqual str(new (new A)), "A(foo)"
	
	m = {}
	m.get = "foo"
	qa.assertEqual str(m), "{""get"": ""foo""}"
end function

testStringToRawData = function
	qa.assertEqual fcgiCodec.stringToRawData("hello world!").utf8, "hello world!"
	qa.assertEqual fcgiCodec.stringToRawData("привіт світе!").utf8, "привіт світе!"
	qa.assertEqual fcgiCodec.stringToRawData("こんにちは世界!").utf8, "こんにちは世界!"
end function

testRawDataToString = function
	r = new RawData
	qa.assertEqual fcgiCodec.rawDataToString(r), ""
	
	r.resize 3
	r.setUtf8 0, "foo"
	qa.assertEqual fcgiCodec.rawDataToString(r), "foo"
	
	r.resize 0
	qa.assertEqual fcgiCodec.rawDataToString(r), ""
end function

testRawDataCmp = function
	stord = @fcgiCodec.stringToRawData
	
	qa.assertEqual fcgiCodec.rawDataCmp(stord(""), stord("")), 0
	qa.assertEqual fcgiCodec.rawDataCmp(stord("A"), stord("")), 1
	qa.assertEqual fcgiCodec.rawDataCmp(stord(""), stord("A")), -1
	qa.assertEqual fcgiCodec.rawDataCmp(stord("A"), stord("A")), 0
	qa.assertEqual fcgiCodec.rawDataCmp(stord("AA"), stord("A")), 1
	qa.assertEqual fcgiCodec.rawDataCmp(stord("A"), stord("AA")), -1
	qa.assertEqual fcgiCodec.rawDataCmp(stord("AA"), stord("AA")), 0
	qa.assertEqual fcgiCodec.rawDataCmp(stord("AB"), stord("AA")), 1
	qa.assertEqual fcgiCodec.rawDataCmp(stord("AB"), stord("BA")), -1
end function




// Tests for RawDataCollection

testRawDataCollection = function
	stord = @fcgiCodec.stringToRawData
	
	r = fcgiCodec.RawDataCollection.make
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 0
	qa.assertEqual r.toRawData.len, 0
	
	r.push stord("foo")
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 3
	qa.assertEqual r.toRawData.utf8, "foo"
	
	r.advance 1
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 2
	qa.assertEqual r.toRawData.utf8, "oo"
	
	r.push "bar"
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 5
	qa.assertEqual r.toRawData.utf8, "oobar"
	
	r.grow -1
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 4
	qa.assertEqual r.toRawData.utf8, "ooba"
	
	r.push stord("baz")
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 7
	qa.assertEqual r.toRawData.utf8, "oobarba"
	
	r.push stord("bamf"), true
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 7
	qa.assertEqual r.toRawData.utf8, "oobarba"
	
	r.grow 1/0
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 12
	qa.assertEqual r.toRawData.utf8, "oobarbazbamf"
	
	r.grow -3
	rdl = r.toRawDataList
	qa.assertEqual rdl.len, 4
	qa.assertEqual rdl[0].utf8, "oo"
	qa.assertEqual rdl[1].utf8, "bar"
	qa.assertEqual rdl[2].utf8, "baz"
	qa.assertEqual rdl[3].utf8, "b"
end function

testRawDataCollectionTotalBytes = function
	stord = @fcgiCodec.stringToRawData
	
	r = fcgiCodec.RawDataCollection.make
	qa.assertEqual r.len, 0
	qa.assertEqual r.totalBytes, 0
	
	r.push "hello"
	qa.assertEqual r.len, 5
	qa.assertEqual r.totalBytes, 5
	
	r.advance 1
	qa.assertEqual r.len, 4
	qa.assertEqual r.totalBytes, 5
	
	r.grow -1
	qa.assertEqual r.len, 3
	qa.assertEqual r.totalBytes, 5
	
	r.push "world"
	qa.assertEqual r.len, 8
	qa.assertEqual r.totalBytes, 10
	
	r2 = fcgiCodec.RawDataCollection.make
	r2.push "foo"
	r2.push r
	r2.push "bar"
	qa.assertEqual r2.len, 3 + 8 + 3
	qa.assertEqual r2.totalBytes, 3 + 8 + 3
end function

testRawDataCollectionPush = function
	r = fcgiCodec.RawDataCollection.make
	
	v = "foo"
	r.push v
	qa.assertEqual r.toRawData.utf8, "foo"
	
	v = new RawData
	v.resize 3
	v.setUtf8 0, "bar"
	r.push v
	qa.assertEqual r.toRawData.utf8, "foobar"
	
	v = fcgiCodec.RawDataCollection.make
	v.push "/bamf/"
	v.grow -1
	v.advance 1
	r.push v
	qa.assertEqual r.toRawData.utf8, "foobarbamf"
	
	v = "boo"
	r.push v, true
	qa.assertEqual r.toRawData.utf8, "foobarbamf"
	
	v = "far"
	r.push v
	qa.assertEqual r.toRawData.utf8, "foobarbamfboo"
end function

testRawDataCollectionTailBytes = function
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	r.push "bar", true
	qa.assertEqual r.tailBytes, 3
	
	r.grow 1
	qa.assertEqual r.tailBytes, 2
	
	r.grow -2
	qa.assertEqual r.tailBytes, 4
	
	r.grow 1/0
	qa.assertEqual r.tailBytes, 0
	
	r.advance 1
	r.grow -1
	qa.assertEqual r.tailBytes, 1
end function

testRawDataCollectionAdvance = function
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	qa.assertEqual r.toRawData.utf8, "foobar"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 6
	qa.assertEqual r.totalBytes, 6
	
	r.advance 1
	qa.assertEqual r.toRawData.utf8, "oobar"
	qa.assertEqual r.offset, 1
	qa.assertEqual r.len, 5
	qa.assertEqual r.totalBytes, 6
	
	r.advance 2
	qa.assertEqual r.toRawData.utf8, "bar"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 3
	qa.assertEqual r.totalBytes, 3
	
	r.advance -1
	qa.assertEqual r.toRawData.utf8, "bar"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 3
	qa.assertEqual r.totalBytes, 3
	
	r.grow -1
	qa.assertEqual r.toRawData.utf8, "ba"
	qa.assertEqual r.offset, 0
	qa.assertEqual r.len, 2
	qa.assertEqual r.totalBytes, 3
	
	r.advance 2
	qa.assertEqual r.toRawData.len, 0
	qa.assertEqual r.offset, 2
	qa.assertEqual r.len, 0
	qa.assertEqual r.totalBytes, 3
end function

testRawDataCollectionGrow = function
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	r.grow -1
	qa.assertEqual r.len, 5
	qa.assertEqual r.toRawData.utf8, "fooba"
	
	r.grow -3
	qa.assertEqual r.len, 2
	qa.assertEqual r.toRawData.utf8, "fo"
	
	r.grow 100
	qa.assertEqual r.len, 6
	qa.assertEqual r.toRawData.utf8, "foobar"
	
	r.grow -1/0
	qa.assertEqual r.len, 0
	qa.assertEqual r.toRawData.len, 0
	
	r.grow 1
	qa.assertEqual r.len, 1
	qa.assertEqual r.toRawData.utf8, "f"
	
	r.advance 2
	qa.assertEqual r.len, 0
	qa.assertEqual r.toRawData.len, 0
	
	r.grow 3
	qa.assertEqual r.len, 3
	qa.assertEqual r.toRawData.utf8, "oba"
end function

testRawDataCollectionToRawData = function
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	v = fcgiCodec.RawDataCollection.make
	v.push "baz"
	v.push "bamf"
	v.advance 1
	v.grow -1
	r.push v
	
	r.push "hello"
	qa.assertEqual r.toRawData.utf8, "foobarazbamhello"
	
	r.advance 2
	r.grow -2
	qa.assertEqual r.toRawData.utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(-1).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(0).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(1).utf8, "barazbamhel"
	qa.assertEqual r.toRawData(2).utf8, "arazbamhel"
	qa.assertEqual r.toRawData(3).utf8, "razbamhel"
	qa.assertEqual r.toRawData(4).utf8, "azbamhel"
	qa.assertEqual r.toRawData(5).utf8, "zbamhel"
	qa.assertEqual r.toRawData(6).utf8, "bamhel"
	qa.assertEqual r.toRawData(7).utf8, "amhel"
	qa.assertEqual r.toRawData(8).utf8, "mhel"
	qa.assertEqual r.toRawData(9).utf8, "hel"
	qa.assertEqual r.toRawData(10).utf8, "el"
	qa.assertEqual r.toRawData(11).utf8, "l"
	qa.assertEqual r.toRawData(12).len, 0
	qa.assertEqual r.toRawData(13).len, 0
	qa.assertEqual r.toRawData(0, 99).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(0, 12).utf8, "obarazbamhel"
	qa.assertEqual r.toRawData(0, 11).utf8, "obarazbamhe"
	qa.assertEqual r.toRawData(0, 10).utf8, "obarazbamh"
	qa.assertEqual r.toRawData(0, 9).utf8, "obarazbam"
	qa.assertEqual r.toRawData(0, 8).utf8, "obarazba"
	qa.assertEqual r.toRawData(0, 7).utf8, "obarazb"
	qa.assertEqual r.toRawData(0, 6).utf8, "obaraz"
	qa.assertEqual r.toRawData(0, 5).utf8, "obara"
	qa.assertEqual r.toRawData(0, 4).utf8, "obar"
	qa.assertEqual r.toRawData(0, 3).utf8, "oba"
	qa.assertEqual r.toRawData(0, 2).utf8, "ob"
	qa.assertEqual r.toRawData(0, 1).utf8, "o"
	qa.assertEqual r.toRawData(0, 0).len, 0
	qa.assertEqual r.toRawData(0, -1).len, 0
	qa.assertEqual r.toRawData(5, 2).utf8, "zb"
end function

testRawDataCollectionToRawDataList = function
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	v = fcgiCodec.RawDataCollection.make
	v.push "baz"
	v.push "bamf"
	v.advance 1
	v.grow -1
	r.push v
	
	r.push "hello"
	qa.assertEqual r.toRawData.utf8, "foobarazbamhello"
	
	r.advance 2
	r.grow -2
	
	rr = r.toRawDataList
	qa.assertEqual rr[0].utf8, "o"
	qa.assertEqual rr[1].utf8, "bar"
	qa.assertEqual rr[2].utf8, "az"
	qa.assertEqual rr[3].utf8, "bam"
	qa.assertEqual rr[4].utf8, "hel"
	
	rr = r.toRawDataList(2)
	qa.assertEqual rr[0].utf8, "ar"
	qa.assertEqual rr[1].utf8, "az"
	qa.assertEqual rr[2].utf8, "bam"
	qa.assertEqual rr[3].utf8, "hel"
	
	rr = r.toRawDataList(2, 6)
	qa.assertEqual rr[0].utf8, "ar"
	qa.assertEqual rr[1].utf8, "az"
	qa.assertEqual rr[2].utf8, "ba"
end function

testRawDataCollectionCopy = function
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	
	c = r.copy
	c.push "bar"
	c.advance 1
	
	qa.assertEqual r.toRawData.utf8, "foo"
	qa.assertEqual c.toRawData.utf8, "oobar"
end function

testRawDataCollectionIndexOf = function
	stord = @fcgiCodec.stringToRawData
	
	r = fcgiCodec.RawDataCollection.make
	r.push "foo"
	r.push "bar"
	
	qa.assertEqual r.indexOf("o"), 1
	qa.assertEqual r.indexOf("ob"), 2
	qa.assertEqual r.indexOf("x"), null
	
	s = "fo"
	qa.assertEqual r.indexOf(stord(s)), 0
	
	r.push "baz"
	s = "a"
	qa.assertEqual r.indexOf(stord(s)), 4
	qa.assertEqual r.indexOf(stord(s), 4), 4  // in "bar"
	qa.assertEqual r.indexOf(stord(s), 5), 7  // in "baz"
	qa.assertEqual r.indexOf(stord(s), 8), null
end function




// Tests for NameValuePairs

testNameValuePairsEncodeDecodeLength = function
	r = fcgiCodec.NameValuePairs.encodeLength(0)
	qa.assertEqual r.len, 1
	qa.assertEqual r.byte(0), 0
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 0
	
	r = fcgiCodec.NameValuePairs.encodeLength(1)
	qa.assertEqual r.len, 1
	qa.assertEqual r.byte(0), 1
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 1
	
	r = fcgiCodec.NameValuePairs.encodeLength(100)
	qa.assertEqual r.len, 1
	qa.assertEqual r.byte(0), 100
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 100
	
	r = fcgiCodec.NameValuePairs.encodeLength(127)
	qa.assertEqual r.len, 1
	qa.assertEqual r.byte(0), 127
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 127
	
	r = fcgiCodec.NameValuePairs.encodeLength(128)
	qa.assertEqual r.len, 4
	qa.assertEqual r.byte(0), 128
	qa.assertEqual r.byte(1), 0
	qa.assertEqual r.byte(2), 0
	qa.assertEqual r.byte(3), 128
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 128
	
	r = fcgiCodec.NameValuePairs.encodeLength(129)
	qa.assertEqual r.len, 4
	qa.assertEqual r.byte(0), 128
	qa.assertEqual r.byte(1), 0
	qa.assertEqual r.byte(2), 0
	qa.assertEqual r.byte(3), 129
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 129
	
	r = fcgiCodec.NameValuePairs.encodeLength(300)
	qa.assertEqual r.len, 4
	qa.assertEqual r.byte(0), 128
	qa.assertEqual r.byte(1), 0
	qa.assertEqual r.byte(2), 1
	qa.assertEqual r.byte(3), 44
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 300
	
	r = fcgiCodec.NameValuePairs.encodeLength(84215045)
	qa.assertEqual r.len, 4
	qa.assertEqual r.byte(0), 128 + 5
	qa.assertEqual r.byte(1), 5
	qa.assertEqual r.byte(2), 5
	qa.assertEqual r.byte(3), 5
	qa.assertEqual fcgiCodec.NameValuePairs.decodeLength(r), 84215045
end function

testNameValuePairsBasic = function
	stord = @fcgiCodec.stringToRawData
	
	p = fcgiCodec.NameValuePairs.make
	qa.assertEqual p.names, []
	qa.assertEqual p.getValue("foo"), null
	qa.assertEqual p.getValue("foo", 42), 42
	
	s = char(3) + char(5) + "foo" + "hello"
	p.pushData s
	qa.assertEqual p.names, ["foo"]
	qa.assertEqual p.getValue("foo"), "hello"
	
	s = char(3) + char(7) + "bar" + "goodbye"
	p.pushData stord(s)
	qa.assertEqual p.names, ["bar", "foo"]
	qa.assertEqual p.getValue("foo"), "hello"
	qa.assertEqual p.getValue("bar"), "goodbye"
	
	rr = []
	rr.push char(3) + char(2) + "b"
	rr.push "az" + "h"
	rr.push "i"
	c = fcgiCodec.RawDataCollection.make(rr)
	p.pushData c
	qa.assertEqual p.names, ["bar", "baz", "foo"]
	qa.assertEqual p.getValue("foo"), "hello"
	qa.assertEqual p.getValue("bar"), "goodbye"
	qa.assertEqual p.getValue("baz"), "hi"
	
	s = p.toRawData.utf8
	qa.assertEqual s.indexOf( char(3) + char(5) + "foo" + "hello"   ) != null, true
	qa.assertEqual s.indexOf( char(3) + char(7) + "bar" + "goodbye" ) != null, true
	qa.assertEqual s.indexOf( char(3) + char(2) + "baz" + "hi"      ) != null, true
	
	s = p.toRawDataString
	qa.assertEqual s.indexOf( char(3) + char(5) + "foo" + "hello"   ) != null, true
	qa.assertEqual s.indexOf( char(3) + char(7) + "bar" + "goodbye" ) != null, true
	qa.assertEqual s.indexOf( char(3) + char(2) + "baz" + "hi"      ) != null, true
	
	s = ""
	for r in p.toRawDataList
		s += r.utf8
	end for
	qa.assertEqual s.indexOf( char(3) + char(5) + "foo" + "hello"   ) != null, true
	qa.assertEqual s.indexOf( char(3) + char(7) + "bar" + "goodbye" ) != null, true
	qa.assertEqual s.indexOf( char(3) + char(2) + "baz" + "hi"      ) != null, true
end function

testNameValuePairsIsComplete = function
	p = fcgiCodec.NameValuePairs.make
	qa.assertEqual p.isComplete, true
	qa.assertEqual p.getValue("foo", 42), 42
	
	p.pushData char(3) + char(3)
	qa.assertEqual p.isComplete, false
	qa.assertEqual p.getValue("foo", 42), 42
	
	p.pushData "fo"
	qa.assertEqual p.isComplete, false
	qa.assertEqual p.getValue("foo", 42), 42
	
	p.pushData "o"
	qa.assertEqual p.isComplete, false
	qa.assertEqual p.getValue("foo", 42), 42
	
	p.pushData "ba"
	qa.assertEqual p.isComplete, false
	qa.assertEqual p.getValue("foo", 42), 42
	
	p.pushData "r"
	qa.assertEqual p.isComplete, true
	qa.assertEqual p.getValue("foo", 42), "bar"
end function

testNameValuePairsSetValue = function
	p = fcgiCodec.NameValuePairs.make
	qa.assertEqual p.toRawDataString, ""
	p.setValue "foo", "hello"
	qa.assertEqual p.toRawDataString, char(3) + char(5) + "foo" + "hello"
end function

testNameValuePairsDeleteValue = function
	p = fcgiCodec.NameValuePairs.make(char(3) + char(5) + "foo" + "hello")
	qa.assertEqual p.getValue("foo", 42), "hello"
	p.deleteValue "foo"
	qa.assertEqual p.getValue("foo", 42), 42
end function

testNameValuePairsHasName = function
	p = fcgiCodec.NameValuePairs.make(char(3) + char(5) + "foo" + "hello")
	qa.assertEqual p.hasName("foo"), true
	qa.assertEqual p.hasName("bar"), false
end function




// Tests for Record

testRecordPaddingLength = function
	qa.assertEqual fcgiCodec.Record.paddingLength(0), 0
	qa.assertEqual fcgiCodec.Record.paddingLength(1), 7
	qa.assertEqual fcgiCodec.Record.paddingLength(7), 1
	qa.assertEqual fcgiCodec.Record.paddingLength(8), 0
	qa.assertEqual fcgiCodec.Record.paddingLength(9), 7
	qa.assertEqual fcgiCodec.Record.paddingLength(15), 1
	qa.assertEqual fcgiCodec.Record.paddingLength(16), 0
	qa.assertEqual fcgiCodec.Record.paddingLength(17), 7
	qa.assertEqual fcgiCodec.Record.paddingLength(23), 1
	qa.assertEqual fcgiCodec.Record.paddingLength(24), 0
end function

testRecordBasic = function
	rec = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_BEGIN_REQUEST,
	                            42,
	                            "hello")  // nonsense content, 5 bytes, padding 3 bytes
	qa.assertEqual rec.recordType, fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual rec.requestId, 42
	qa.assertEqual rec.body.utf8, "hello"
	
	r = rec.toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 5
	qa.assertEqual r.byte(6), 3
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 5), "hello"
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
	
	rec = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_BEGIN_REQUEST,
	                            42,
	                            "goodbye world!")  // nonsense content, 14 bytes, padding 2 bytes
	qa.assertEqual rec.recordType, fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual rec.requestId, 42
	qa.assertEqual rec.body.utf8, "goodbye world!"
	
	r = rec.toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 14
	qa.assertEqual r.byte(6), 2
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 14), "goodbye world!"
	qa.assertEqual r.byte(22), 0
	qa.assertEqual r.byte(23), 0
	
	rec = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_UNKNOWN_TYPE,
	                            42,
	                            "unknown world!!!")  // nonsense content, 16 bytes, no padding
	qa.assertEqual rec.recordType, fcgiCodec.recordType.FCGI_UNKNOWN_TYPE
	qa.assertEqual rec.requestId, 42
	qa.assertEqual rec.body.utf8, "unknown world!!!"
	
	r = rec.toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_UNKNOWN_TYPE
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 16
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 16), "unknown world!!!"
	
	rec = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDOUT,
	                            42,
	                            "")  // nonsense content, empty, no padding
	qa.assertEqual rec.recordType, fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual rec.requestId, 42
	qa.assertEqual rec.body.len, 0
	
	r = rec.toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testRecordIsStreamType = function
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_BEGIN_REQUEST),     false
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_ABORT_REQUEST),     false
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_END_REQUEST),       false
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_PARAMS),            true
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_STDIN),             true
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_STDOUT),            true
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_STDERR),            true
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_DATA),              true
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_GET_VALUES),        false
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_GET_VALUES_RESULT), false
	qa.assertEqual fcgiCodec.Record.isStreamType(fcgiCodec.recordType.FCGI_UNKNOWN_TYPE),      false
end function




// Tests for *Msg classes

testMsgGetClass = function
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_BEGIN_REQUEST),     fcgiCodec.BeginRequestMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_ABORT_REQUEST),     fcgiCodec.AbortRequestMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_END_REQUEST),       fcgiCodec.EndRequestMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_PARAMS),            fcgiCodec.ParamsMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_STDIN),             fcgiCodec.StdinMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_STDOUT),            fcgiCodec.StdoutMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_STDERR),            fcgiCodec.StderrMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_DATA),              fcgiCodec.DataMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_GET_VALUES),        fcgiCodec.GetValuesMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_GET_VALUES_RESULT), fcgiCodec.GetValuesResultMsg
	qa.assertEqual fcgiCodec.Msg.getClass(fcgiCodec.recordType.FCGI_UNKNOWN_TYPE),      fcgiCodec.UnknownTypeMsg
end function

testBeginRequestMsg = function
	m = fcgiCodec.BeginRequestMsg.make(42, fcgiCodec.role.FCGI_RESPONDER, true)
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.role, fcgiCodec.role.FCGI_RESPONDER
	qa.assertEqual m.keepConnectionP, true
	
	c = m.collection
	r = c.toRawData
	r.littleEndian = false
	qa.assertEqual r.ushort(0), fcgiCodec.role.FCGI_RESPONDER
	qa.assertEqual r.byte(2), fcgiCodec.flag.FCGI_KEEP_CONN
	qa.assertEqual r.byte(3), 0
	qa.assertEqual r.byte(4), 0
	qa.assertEqual r.byte(5), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords
	qa.assertEqual recs.len, 1
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 8
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.ushort(8), fcgiCodec.role.FCGI_RESPONDER
	qa.assertEqual r.byte(10), fcgiCodec.flag.FCGI_KEEP_CONN
	qa.assertEqual r.byte(11), 0
	qa.assertEqual r.byte(12), 0
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
end function

testAbortRequestMsg = function
	m = fcgiCodec.AbortRequestMsg.make(42)
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_ABORT_REQUEST
	qa.assertEqual m.requestId, 42
	
	c = m.collection
	r = c.toRawData
	qa.assertEqual r.len, 0
	
	recs = m.toRecords
	qa.assertEqual recs.len, 1
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_ABORT_REQUEST
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testEndRequestMsg = function
	m = fcgiCodec.EndRequestMsg.make(42, 1337, fcgiCodec.protoStatus.FCGI_REQUEST_COMPLETE)
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_END_REQUEST
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.appStatus, 1337
	qa.assertEqual m.protoStatus, fcgiCodec.protoStatus.FCGI_REQUEST_COMPLETE
	
	c = m.collection
	r = c.toRawData
	r.littleEndian = false
	qa.assertEqual r.uint(0), 1337
	qa.assertEqual r.byte(4), fcgiCodec.protoStatus.FCGI_REQUEST_COMPLETE
	qa.assertEqual r.byte(5), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords
	qa.assertEqual recs.len, 1
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_END_REQUEST
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 8
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.uint(8), 1337
	qa.assertEqual r.byte(12), fcgiCodec.protoStatus.FCGI_REQUEST_COMPLETE
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
end function

testParamsMsg = function
	m = fcgiCodec.ParamsMsg.make(42, {"foo": "hello", "bar": "goodbye"})
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_PARAMS
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.paramsMap, {"foo": "hello", "bar": "goodbye"}
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, char(3) + char(7) + "bar" + "goodbye" + char(3) + char(5) + "foo" + "hello"
	
	recs = m.toRecords
	qa.assertEqual recs.len, 2
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 32
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_PARAMS
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 22
	qa.assertEqual r.byte(6), 2
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 22), char(3) + char(7) + "bar" + "goodbye" + char(3) + char(5) + "foo" + "hello"
	qa.assertEqual r.byte(30), 0
	qa.assertEqual r.byte(31), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_PARAMS
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords(20)
	qa.assertEqual recs.len, 3
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 32
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_PARAMS
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 20
	qa.assertEqual r.byte(6), 4
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 20), char(3) + char(7) + "bar" + "goodbye" + char(3) + char(5) + "foo" + "hel"
	qa.assertEqual r.byte(28), 0
	qa.assertEqual r.byte(29), 0
	qa.assertEqual r.byte(30), 0
	qa.assertEqual r.byte(31), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_PARAMS
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 2
	qa.assertEqual r.byte(6), 6
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 2), "lo"
	qa.assertEqual r.byte(10), 0
	qa.assertEqual r.byte(11), 0
	qa.assertEqual r.byte(12), 0
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
	r = recs[2].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_PARAMS
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testStdinMsg = function
	m = fcgiCodec.StdinMsg.make(42, "hello world!")
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.data.utf8, "hello world!"
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, "hello world!"
	
	recs = m.toRecords
	qa.assertEqual recs.len, 2
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 12
	qa.assertEqual r.byte(6), 4
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 12), "hello world!"
	qa.assertEqual r.byte(20), 0
	qa.assertEqual r.byte(21), 0
	qa.assertEqual r.byte(22), 0
	qa.assertEqual r.byte(23), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords(7)
	qa.assertEqual recs.len, 3
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 7
	qa.assertEqual r.byte(6), 1
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 7), "hello w"
	qa.assertEqual r.byte(15), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 5
	qa.assertEqual r.byte(6), 3
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 5), "orld!"
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
	r = recs[2].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testStdoutMsg = function
	m = fcgiCodec.StdoutMsg.make(42, "hello world!")
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.data.utf8, "hello world!"
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, "hello world!"
	
	recs = m.toRecords
	qa.assertEqual recs.len, 2
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 12
	qa.assertEqual r.byte(6), 4
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 12), "hello world!"
	qa.assertEqual r.byte(20), 0
	qa.assertEqual r.byte(21), 0
	qa.assertEqual r.byte(22), 0
	qa.assertEqual r.byte(23), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords(7)
	qa.assertEqual recs.len, 3
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 7
	qa.assertEqual r.byte(6), 1
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 7), "hello w"
	qa.assertEqual r.byte(15), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 5
	qa.assertEqual r.byte(6), 3
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 5), "orld!"
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
	r = recs[2].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testStderrMsg = function
	m = fcgiCodec.StderrMsg.make(42, "hello world!")
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.data.utf8, "hello world!"
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, "hello world!"
	
	recs = m.toRecords
	qa.assertEqual recs.len, 2
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 12
	qa.assertEqual r.byte(6), 4
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 12), "hello world!"
	qa.assertEqual r.byte(20), 0
	qa.assertEqual r.byte(21), 0
	qa.assertEqual r.byte(22), 0
	qa.assertEqual r.byte(23), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords(7)
	qa.assertEqual recs.len, 3
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 7
	qa.assertEqual r.byte(6), 1
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 7), "hello w"
	qa.assertEqual r.byte(15), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 5
	qa.assertEqual r.byte(6), 3
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 5), "orld!"
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
	r = recs[2].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testDataMsg = function
	m = fcgiCodec.DataMsg.make(42, "hello world!")
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_DATA
	qa.assertEqual m.requestId, 42
	qa.assertEqual m.data.utf8, "hello world!"
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, "hello world!"
	
	recs = m.toRecords
	qa.assertEqual recs.len, 2
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_DATA
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 12
	qa.assertEqual r.byte(6), 4
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 12), "hello world!"
	qa.assertEqual r.byte(20), 0
	qa.assertEqual r.byte(21), 0
	qa.assertEqual r.byte(22), 0
	qa.assertEqual r.byte(23), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_DATA
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords(7)
	qa.assertEqual recs.len, 3
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_DATA
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 7
	qa.assertEqual r.byte(6), 1
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 7), "hello w"
	qa.assertEqual r.byte(15), 0
	r = recs[1].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_DATA
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 5
	qa.assertEqual r.byte(6), 3
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 5), "orld!"
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
	r = recs[2].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 8
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_DATA
	qa.assertEqual r.ushort(2), 42
	qa.assertEqual r.ushort(4), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
end function

testGetValuesMsg = function
	m = fcgiCodec.GetValuesMsg.make(["bar", "foo"])
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_GET_VALUES
	qa.assertEqual m.requestId, 0
	qa.assertEqual m.names, ["bar", "foo"]
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, char(3) + char(0) + "bar" + "" + char(3) + char(0) + "foo" + ""
	
	recs = m.toRecords
	qa.assertEqual recs.len, 1
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 24
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_GET_VALUES
	qa.assertEqual r.ushort(2), 0
	qa.assertEqual r.ushort(4), 10
	qa.assertEqual r.byte(6), 6
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 10), char(3) + char(0) + "bar" + "" + char(3) + char(0) + "foo" + ""
	qa.assertEqual r.byte(18), 0
	qa.assertEqual r.byte(19), 0
	qa.assertEqual r.byte(20), 0
	qa.assertEqual r.byte(21), 0
	qa.assertEqual r.byte(22), 0
	qa.assertEqual r.byte(23), 0
end function

testGetValuesResultMsg = function
	m = fcgiCodec.GetValuesResultMsg.make({"foo": "hello", "bar": "goodbye"})
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_GET_VALUES_RESULT
	qa.assertEqual m.requestId, 0
	qa.assertEqual m.valuesMap, {"foo": "hello", "bar": "goodbye"}
	
	c = m.collection
	qa.assertEqual c.toRawData.utf8, char(3) + char(7) + "bar" + "goodbye" + char(3) + char(5) + "foo" + "hello"
	
	recs = m.toRecords
	qa.assertEqual recs.len, 1
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 32
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_GET_VALUES_RESULT
	qa.assertEqual r.ushort(2), 0
	qa.assertEqual r.ushort(4), 22
	qa.assertEqual r.byte(6), 2
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.utf8(8, 22), char(3) + char(7) + "bar" + "goodbye" + char(3) + char(5) + "foo" + "hello"
	qa.assertEqual r.byte(30), 0
	qa.assertEqual r.byte(31), 0
end function

testUnknownTypeMsg = function
	m = fcgiCodec.UnknownTypeMsg.make(100)
	qa.assertEqual m.recordType, fcgiCodec.recordType.FCGI_UNKNOWN_TYPE
	qa.assertEqual m.requestId, 0
	qa.assertEqual m.unknownType, 100
	
	c = m.collection
	r = c.toRawData
	r.littleEndian = false
	qa.assertEqual r.byte(0), 100
	qa.assertEqual r.byte(1), 0
	qa.assertEqual r.byte(2), 0
	qa.assertEqual r.byte(3), 0
	qa.assertEqual r.byte(4), 0
	qa.assertEqual r.byte(5), 0
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	
	recs = m.toRecords
	qa.assertEqual recs.len, 1
	r = recs[0].toRawData
	r.littleEndian = false
	qa.assertEqual r.len, 16
	qa.assertEqual r.byte(0), fcgiCodec.proto.FCGI_VERSION_1
	qa.assertEqual r.byte(1), fcgiCodec.recordType.FCGI_UNKNOWN_TYPE
	qa.assertEqual r.ushort(2), 0
	qa.assertEqual r.ushort(4), 8
	qa.assertEqual r.byte(6), 0
	qa.assertEqual r.byte(7), 0
	qa.assertEqual r.byte(8), 100
	qa.assertEqual r.byte(9), 0
	qa.assertEqual r.byte(10), 0
	qa.assertEqual r.byte(11), 0
	qa.assertEqual r.byte(12), 0
	qa.assertEqual r.byte(13), 0
	qa.assertEqual r.byte(14), 0
	qa.assertEqual r.byte(15), 0
end function




// Tests for RecordDecoder

testRecordDecoderBasic = function
	r1 = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDIN, 100, "")
	r2 = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDOUT, 200, "foo")
	r3 = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDERR, 300, "hello world!")
	
	rdec = fcgiCodec.RecordDecoder.make
	r = rdec.getRecord
	qa.assertEqual r, null
	
	rdec.pushData r1.toRawData
	r = rdec.getRecord
	qa.assertEqual r.recordType, fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual r.requestId, 100
	qa.assertEqual r.body.len, 0
	r = rdec.getRecord
	qa.assertEqual r, null
	
	rdec.pushData r2.toRawData
	rdec.pushData r3.toRawData
	r = rdec.getRecord
	qa.assertEqual r.recordType, fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual r.requestId, 200
	qa.assertEqual r.body.utf8, "foo"
	r = rdec.getRecord
	qa.assertEqual r.recordType, fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual r.requestId, 300
	qa.assertEqual r.body.utf8, "hello world!"
	r = rdec.getRecord
	qa.assertEqual r, null
end function

testRecordDecoderOnError = function
	
	out = {}
	_onError = function(errCode, arg1)
		out.errCode = errCode
		out.arg1 = arg1
	end function
	
	r = new RawData
	r.resize 8
	r.setByte 0, 2  // no such protocol version
	rdec = fcgiCodec.RecordDecoder.make
	rdec.pushData r, @_onError
	qa.assertEqual out.errCode, "UNKNOWN_PROTO"
	qa.assertEqual out.arg1, 2
	
	r = new RawData
	r.resize 8
	r.setByte 0, fcgiCodec.proto.FCGI_VERSION_1
	r.setByte 1, 100  // no such record type
	rdec = fcgiCodec.RecordDecoder.make
	rdec.pushData r, @_onError
	qa.assertEqual out.errCode, "UNKNOWN_RECORD_TYPE"
	qa.assertEqual out.arg1, 100
end function

testRecordDecoderGetAllRecords = function
	r1 = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDIN, 100, "")
	r2 = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDOUT, 200, "foo")
	r3 = fcgiCodec.Record.make(fcgiCodec.recordType.FCGI_STDERR, 300, "hello world!")
	
	rdec = fcgiCodec.RecordDecoder.make
	rdec.pushData r1.toRawData
	rdec.pushData r2.toRawData
	rdec.pushData r3.toRawData
	
	rr = rdec.getAllRecords
	qa.assertEqual rr.len, 3
	qa.assertEqual rr[0].recordType, fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual rr[0].requestId, 100
	qa.assertEqual rr[0].body.len, 0
	qa.assertEqual rr[1].recordType, fcgiCodec.recordType.FCGI_STDOUT
	qa.assertEqual rr[1].requestId, 200
	qa.assertEqual rr[1].body.utf8, "foo"
	qa.assertEqual rr[2].recordType, fcgiCodec.recordType.FCGI_STDERR
	qa.assertEqual rr[2].requestId, 300
	qa.assertEqual rr[2].body.utf8, "hello world!"
end function




// Tests for Bucket

testBucketBeginRequest = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.role, fcgiCodec.role.FCGI_FILTER
	qa.assertEqual out.request.keepConnectionP, false
	m1 = out.request[fcgiCodec.recordType.FCGI_BEGIN_REQUEST]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.role, fcgiCodec.role.FCGI_FILTER
	qa.assertEqual m1.keepConnectionP, false
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketAbortRequest = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.AbortRequestMsg.make(100)
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.isAborted, true
	m1 = out.request[fcgiCodec.recordType.FCGI_ABORT_REQUEST]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketEndRequest = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.EndRequestMsg.make(100, 1337, fcgiCodec.protoStatus.FCGI_OVERLOADED)
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.appStatus, 1337
	qa.assertEqual out.request.protoStatus, fcgiCodec.protoStatus.FCGI_OVERLOADED
	m1 = out.request[fcgiCodec.recordType.FCGI_END_REQUEST]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.appStatus, 1337
	qa.assertEqual m1.protoStatus, fcgiCodec.protoStatus.FCGI_OVERLOADED
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketParams = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.ParamsMsg.make(100, {"foo": "hello", "bar": "goodbye"})
	rr = m.toRecords
	b.pushRecord rr[0]
	b.pushRecord rr[1]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.params["foo"], "hello"
	qa.assertEqual out.request.params["bar"], "goodbye"
	qa.assertEqual out.request.paramsPairs.getValue("foo"), "hello"
	qa.assertEqual out.request.paramsPairs.getValue("bar"), "goodbye"
	m1 = out.request[fcgiCodec.recordType.FCGI_PARAMS]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.pairs.getValue("foo"), "hello"
	qa.assertEqual m1.pairs.getValue("bar"), "goodbye"
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketStdin = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.StdinMsg.make(100, "hello world!")
	rr = m.toRecords
	b.pushRecord rr[0]
	b.pushRecord rr[1]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.stdin.utf8, "hello world!"
	qa.assertEqual out.request.stdinString, "hello world!"
	m1 = out.request[fcgiCodec.recordType.FCGI_STDIN]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.data.utf8, "hello world!"
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketStdout = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.StdoutMsg.make(100, "hello world!")
	rr = m.toRecords
	b.pushRecord rr[0]
	b.pushRecord rr[1]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.stdout.utf8, "hello world!"
	qa.assertEqual out.request.stdoutString, "hello world!"
	m1 = out.request[fcgiCodec.recordType.FCGI_STDOUT]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.data.utf8, "hello world!"
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketStderr = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.StderrMsg.make(100, "hello world!")
	rr = m.toRecords
	b.pushRecord rr[0]
	b.pushRecord rr[1]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.stderr.utf8, "hello world!"
	qa.assertEqual out.request.stderrString, "hello world!"
	m1 = out.request[fcgiCodec.recordType.FCGI_STDERR]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.data.utf8, "hello world!"
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketData = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.DataMsg.make(100, "hello world!")
	rr = m.toRecords
	b.pushRecord rr[0]
	b.pushRecord rr[1]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	
	out = {}
	b.handleOne 100, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 100
	qa.assertEqual out.request.data.utf8, "hello world!"
	qa.assertEqual out.request.dataString, "hello world!"
	m1 = out.request[fcgiCodec.recordType.FCGI_DATA]
	qa.assertEqual m1.requestId, 100
	qa.assertEqual m1.data.utf8, "hello world!"
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketGetValues = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.GetValuesMsg.make(["bar", "foo"])
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [0]
	
	out = {}
	b.handleOne 0, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 0
	qa.assertEqual out.request.names, ["bar", "foo"]
	m1 = out.request[fcgiCodec.recordType.FCGI_GET_VALUES]
	qa.assertEqual m1.requestId, 0
	qa.assertEqual m1.names, ["bar", "foo"]
	qa.assertEqual m1.nameSet, {"bar": true, "foo": true}
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketGetValuesResult = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.GetValuesResultMsg.make({"foo": "hello", "bar": "goodbye"})
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [0]
	
	out = {}
	b.handleOne 0, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 0
	qa.assertEqual out.request.result["foo"], "hello"
	qa.assertEqual out.request.result["bar"], "goodbye"
	qa.assertEqual out.request.resultPairs.getValue("foo"), "hello"
	qa.assertEqual out.request.resultPairs.getValue("bar"), "goodbye"
	m1 = out.request[fcgiCodec.recordType.FCGI_GET_VALUES_RESULT]
	qa.assertEqual m1.requestId, 0
	qa.assertEqual m1.pairs.getValue("foo"), "hello"
	qa.assertEqual m1.pairs.getValue("bar"), "goodbye"
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketUnknownType = function
	b = fcgiCodec.Bucket.make
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	
	m = fcgiCodec.UnknownTypeMsg.make(42)
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [0]
	
	out = {}
	b.handleOne 0, out, function(request, arg)
		arg.request = request
		return true
	end function
	qa.assertEqual out.request.requestId, 0
	qa.assertEqual out.request.unknownType, 42
	m1 = out.request[fcgiCodec.recordType.FCGI_UNKNOWN_TYPE]
	qa.assertEqual m1.requestId, 0
	qa.assertEqual m1.unknownType, 42
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketPushRecordOnError = function
	
	out = {}
	_onError = function(errCode, arg1, arg2)
		out.errCode = errCode
		out.arg1 = arg1
		out.arg2 = arg2
	end function
	
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	b.pushRecord rr[0]
	out = {}
	b.pushRecord rr[0], @_onError  // pushing a message of the same type for the same request ID
	qa.assertEqual out.errCode, "DIRTY_BUCKET"
	qa.assertEqual out.arg1, fcgiCodec.recordType.FCGI_BEGIN_REQUEST
	qa.assertEqual out.arg2, 100
	
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	rr[0].rdcol.grow -1  // dropping 1 byte
	out = {}
	b.pushRecord rr[0], @_onError
	qa.assertEqual out.errCode, "BODY_TOO_SHORT"
	qa.assertEqual out.arg1, 8
	qa.assertEqual out.arg2, 7
	
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	d = new RawData
	d.resize 8
	d.littleEndian = false
	d.setUshort 0, 42
	rr[0].rdcol = fcgiCodec.RawDataCollection.make(d)
	out = {}
	b.pushRecord rr[0], @_onError
	qa.assertEqual out.errCode, "UNKNOWN_ROLE"
	qa.assertEqual out.arg1, 42  // no such role
	qa.assertEqual out.arg2, null
	
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.EndRequestMsg.make(100, 1337, fcgiCodec.protoStatus.FCGI_UNKNOWN_ROLE)
	rr = m.toRecords
	
	d = new RawData
	d.resize 8
	d.littleEndian = false
	d.setByte 4, 42  // no such protocol status
	rr[0].rdcol = fcgiCodec.RawDataCollection.make(d)
	out = {}
	b.pushRecord rr[0], @_onError
	qa.assertEqual out.errCode, "UNKNOWN_PROTO_STATUS"
	qa.assertEqual out.arg1, 42
	qa.assertEqual out.arg2, null
	
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.UnknownTypeMsg.make(42)
	rr = m.toRecords
	rr[0].rdcol.grow -1  // dropping 1 byte
	out = {}
	b.pushRecord rr[0], @_onError
	qa.assertEqual out.errCode, "BODY_TOO_SHORT"
	qa.assertEqual out.arg1, 8
	qa.assertEqual out.arg2, 7
	
	b = fcgiCodec.Bucket.make
	for i in range(1, 101)
		m = fcgiCodec.StdinMsg.make(i, "foo")
		rr = m.toRecords
		out = {}
		b.pushRecord rr[0], @_onError
	end for
	qa.assertEqual out.errCode, "TOO_MANY_MSGS"
	qa.assertEqual out.arg1, null
	qa.assertEqual out.arg2, null
	
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.StdinMsg.make(100, "foo")
	rr = m.toRecords
	for i in range(1, 101)
		out = {}
		b.pushRecord rr[0], @_onError
	end for
	qa.assertEqual out.errCode, "TOO_MANY_RECORDS"
	qa.assertEqual out.arg1, fcgiCodec.recordType.FCGI_STDIN
	qa.assertEqual out.arg2, 100
end function

testBucketHandleAll = function
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	b.pushRecord rr[0]
	m = fcgiCodec.BeginRequestMsg.make(300, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	b.pushRecord rr[0]
	m = fcgiCodec.BeginRequestMsg.make(200, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 3
	qa.assertEqual b.requestIds, [100, 200, 300]
	
	rids = []
	b.handleAll rids, function(request, arg)
		arg.push request.requestId
		return true
	end function
	qa.assertEqual rids, [100, 200, 300]
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
end function

testBucketRemoveRequest = function
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	b.pushRecord rr[0]
	qa.assertEqual b.nRequests, 1
	qa.assertEqual b.requestIds, [100]
	req = b.removeRequest(100)
	qa.assertEqual b.nRequests, 0
	qa.assertEqual b.requestIds, []
	qa.assertEqual req.requestId, 100
	qa.assertEqual req.role, fcgiCodec.role.FCGI_FILTER
	qa.assertEqual req.keepConnectionP, false
end function

testBucketPushManyRecords = function
	b = fcgiCodec.Bucket.make
	m = fcgiCodec.BeginRequestMsg.make(100, fcgiCodec.role.FCGI_FILTER, false)
	rr = m.toRecords
	m = fcgiCodec.BeginRequestMsg.make(300, fcgiCodec.role.FCGI_FILTER, false)
	rr += m.toRecords
	m = fcgiCodec.BeginRequestMsg.make(200, fcgiCodec.role.FCGI_FILTER, false)
	rr += m.toRecords
	
	b.pushManyRecords rr
	qa.assertEqual b.nRequests, 3
	qa.assertEqual b.requestIds, [100, 200, 300]
end function
