import "importUtil"

ensureImport "qa"

if not globals.hasIndex("_EOL") then globals._EOL = char(10)

globals.patchGlobal = function(name, newValue)
	if not globals.hasIndex("patched") then globals.patched = {}
	if not patched.hasIndex(name) then patched[name] = []
	if globals.hasIndex(name) then patched[name].push globals[name]
	globals[name] = @newValue
end function

globals.restoreGlobal = function(name)
	if not globals.hasIndex("patched") then globals.patched = {}
	if not patched.hasIndex(name) then patched[name] = []
	if patched[name].len > 0 then
		globals[name] = patched[name].pop
	else
		globals.remove name
	end if
end function

// assertEqual: Similar to `qa.assertEqual` but fits the message on one Mini Micro screen.
qa.assertEqual = function(actual, expected, note = null)
	if @actual == @expected then return
	
	// Converts to string and cuts to 35 characters to save screen space.
	_chop35 = function(x)
		s = str(@x)
		if s.len > 35 then s = s[:35] + "…"
		unprintables = range(31) + [127]
		cc = []
		for c in s
			if unprintables.indexOf(c.code) == null then
				cc.push c
			else
				cc.push char(134) + "<char" + c.code + ">" + char(135)
			end if
		end for
		return cc.join("")
	end function
	
	msg = "Assert failed"
	if note != null then msg += " (" + note + ")"
	msg += ": expected `" + _chop35(@expected) + "`, but got `" + _chop35(@actual) + "`"
	if (@actual isa string and @expected isa string) or
		(@actual isa list and @expected isa list) or
		(@actual isa map and @expected isa map) then
		// If same type, find and report any first discrepancy
		found = false
		idx = null
		vals = null
		codes = null
		for k in actual.indexes
			if not expected.hasIndex(@k) then
				// Found unexpected data among keys in actual
				idx = "`" + _chop35(@k) + "`"
				if actual isa map then
					vals = ["no such index", "{…: `" + _chop35(actual[@k]) + "` …}"]
				else if k > 0 then
					vals = ["end of data", "`…" + _chop35(actual[k:]) + "`"]
				end if
				found = true
				break
			else if actual[@k] != expected[@k] then
				// Found different values of the same key
				idx = "`" + _chop35(@k) + "`"
				if actual isa map then
					vals = ["{…: `" + _chop35(expected[@k]) + "` …}", "{…: `" + _chop35(actual[@k]) + "` …}"]
				else if k > 0 then
					vals = ["`…" + _chop35(expected[k:]) + "`", "`…" + _chop35(actual[k:]) + "`"]
					if actual isa string then codes = [expected[k].code, actual[k].code]
				end if
				found = true
				break
			end if
		end for
		if not found then
			// We didn't find difference iterating over actual keys, which means that some expected data is missing
			if actual isa map then
				for k in expected.indexes
					if not actual.hasIndex(@k) then break
				end for
			else
				k = actual.len
			end if
			idx = "`" + _chop35(@k) + "`"
			if actual isa map then
				vals = ["{…: `" + _chop35(expected[@k]) + "` …}", "no such index"]
			else if k > 0 then
				vals = ["`…" + _chop35(expected[k:]) + "`", "end of data"]
			end if
			found = true
		end if
		// Engooden error message
		msg += _EOL + "At index " + @idx
		if vals then
			exp = vals[0]
			act = vals[1]
			if actual isa list then
				if exp[:3] == "`…[" then exp = "`…" + exp[3:]
				if act[:3] == "`…[" then act = "`…" + act[3:]
			end if
			msg += _EOL + char(9) + "expected " + exp
			msg += _EOL + char(9) + "but got  " + act
		end if
		if codes then
			msg += _EOL + char(9) + "           ↑"
			msg += _EOL + char(9) + "           code(" + codes[0] + ") != code(" + codes[1] + ")"
		end if
	end if
	qa.abort msg
end function

getSpecs = function(args)
	specs = []
	specIndexes = {}
	for arg in args
		sList = arg.split(":")
		testFile = sList[0]
		if specIndexes.hasIndex(testFile) then
			spec = specs[specIndexes[testFile]]
		else
			spec = {
				"testFile": testFile,
				"functions": [],
			}
			specs.push spec
			specIndexes[testFile] = specs.len - 1
		end if
		if sList.len > 1 then spec.functions.push sList[1]
	end for
	if specs.len == 0 then
		for testFile in file.children("tests")
			if testFile[:4] != "test" then continue
			specs.push {
				"testFile": file.child("tests", testFile),
				"functions": [],
			}
		end for
	end if
	return specs
end function

runCase = function(module, case)
	if module.hasIndex("toBePatched") then
		for kv in module.toBePatched
			patchGlobal @kv.key, @kv.value
		end for
	end if
	if module.hasIndex("setUp") then module.setUp
	case
	if module.hasIndex("tearDown") then module.tearDown
	if module.hasIndex("toBePatched") then
		for kv in module.toBePatched
			restoreGlobal @kv.key
		end for
	end if
end function

runSpec = function(spec)
	
	//
	print " " + spec.testFile + " ", ""
	//
	
	if not file.exists(spec.testFile) then
		
		//
		print "(no such file!)"
		//
		
		return
	end if
	module = importAndReturn(spec.testFile)
	nTests = 0
	if spec.functions.len > 0 then
		
		//
		print "(" + spec.functions.len + ") ", ""
		//
		
		for funcName in spec.functions
			if not module.hasIndex(funcName) then
				
				//
				print "(no such function: `" + str(funcName) + "`!)", ""
				//
				
			else
				func = module[funcName]
				runCase module, @func
				yield
				nTests += 1
				
				//
				print ".", ""
				//
				
			end if
		end for
	else
		for kv in module
			if kv.key[:4] != "test" then continue
			runCase module, @kv.value
			yield
			nTests += 1
			
			//
			print ".", ""
			//
			
		end for
	end if
	
	//
	print " " + nTests
	//
	
	return nTests
end function

launch = function
	addImportPaths ["tests"]
	specs = getSpecs(cmdLine.args)
	nTests = 0
	for spec in specs
		nTests += runSpec(spec)
	end for
	
	//
	print nTests + " OK"
	//
	
end function
