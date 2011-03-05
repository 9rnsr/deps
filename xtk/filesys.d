module xtk.filesys;

public import std.file;
public import std.path;
import std.process, std.array;
alias std.path.defaultExt defExt;

//debug = 1;
debug(1) import std.stdio;

version (Windows):

string which(string name)
{
	auto path = environment["PATH"];
	debug(1) writefln("%s", path);
	return which(name, split(path, pathsep));
}

string which(string name, string pathes[])
{
	auto exe = defExt(name, "exe");
	assert(exe.basename == exe);
	debug(1) writefln("exe = %s", exe);
	
	version (Windows) pathes = `.\` ~ pathes;
	debug(1) writefln("pathes = %s", pathes);
	
	foreach (path; pathes)
	{
		auto abs_exe = std.path.join(path, exe).rel2abs;	// drive nameまで結合されない…
		debug(1) writefln("abs_exe = %s", abs_exe);
		if (abs_exe.exists)
			return abs_exe;
	}
	return null;
}
