import "importUtil"

// importAndReturn: Imports a file path and returns the module object.
importAndReturn = function(path)
	moduleName = file.name(path) - ".ms"
	import moduleName
	return locals[moduleName]
end function

// addImportPaths: Adds directories `dirs` to the import paths.
addImportPaths = function(dirs)
	if not dirs then return
	if env.hasIndex("importPaths") then
		env.importPaths += dirs
	else if env.hasIndex("MS_IMPORT_PATH") then
		env.MS_IMPORT_PATH += ":" + dirs.join(":")
	end if
end function

// getCmdParams: Gets the list of command line parameters.
getCmdParams = function
	if env.hasIndex("cmdLineArgs") then
		return env.cmdLineArgs
	else
		return shellArgs
	end if
end function

// parseCmdLineArgs: Parses the command line parameters and returns a list of arguments and a map of options.
parseCmdLineArgs = function(params = null)
	if params == null then params = getCmdParams
	args = []
	opts = {}
	prevOpt = null
	noOptP = false
	for param in params
		if param == "--" then
			noOptP = true
		else if noOptP then
			args.push param
		else if param[0] == "-" then
			prevOpt = param[1:]
			opts[prevOpt] = true
		else if prevOpt then
			opts[prevOpt] = param
			prevOpt = null
		else
			args.push param
		end if
	end for
	return {"args": args, "opts": opts}
end function

main = function
	addImportPaths ["lib", "cmd"]
	
	globals.cmdLine = parseCmdLineArgs
	cmdLine.args.pull  // drop the program name
	cmdLine.command = cmdLine.args.pull
	
	if cmdLine.command then
		path = file.child("cmd", cmdLine.command)
		files = [path, path + ".ms"]
		for f in files
			if file.exists(f) then return importAndReturn(f).launch
		end for
		ensureImport "qa"
		qa.abort "no such command in `cmd/`: `" + str(cmdLine.command) + "`"
	end if
end function

if refEquals(locals, globals) then main
