import std.string;
import std.format;
import std.stdio;
import std.algorithm;
import std.array;

import xtk.hash;
import xtk.filesys;

import std.typecons;

//debug = PrintDeps;

string curdir;
string objdir;

class Module
{
	alias Hashable!(Tuple!(string, "m", string, "f")) Mod;
	
//	static Module[Mod] modules;
	static Module[string] modules;	// filename -> Module

	static Module get(string m, string f)
	{
//		if (auto pmod = Mod(m, f) in modules)
		if (auto pmod = f in modules)
			return *pmod;
		else
//			return modules[Mod(m, f)] = new Module(m, f);
			return modules[f] = new Module(m, f);
	}
	
	this(string m, string f)
	{
		mname = m, fname = f;
		ftime = timeLastModified(f);
		string oname = std.path.join(
			(objdir ? objdir : curdir), f.basename.setExt("obj"));
		otime = timeLastModified(oname, SysTime.min);
		
		debug(PrintDeps) writefln("module = %s", m);
		debug(PrintDeps) writefln("     f = %s (%s)", ftime, fname);
		debug(PrintDeps) writefln("     o = %s (%s)", otime, oname);
		if (otime < ftime)
			recons = true;
	}
	
	void depends(string srcm, string srcf)
	{
		auto src = Module.get(srcm , srcf);
		if (src !in sources)
		{
			sources[src] = true;	// set
			if (!recons)
			{
				if (this.otime < src.ftime)
					recons = true;
			}
		}
	}
	
	string mname, fname;
	SysTime ftime, otime;
	bool recons;
	bool[Module] sources;	// set
}


import std.process;

import std.getopt;

void main(string[] args)
{
	if (args.length == 1)
	{
		writefln("usage : deps");
		return;
	}
	
	curdir = std.file.getcwd();
	getopt(args,
		"od",	&objdir
	);
	debug(PrintDeps) writefln("curdir = %s, objdir = %s", curdir, objdir);
	
	auto fname = args[1];
	debug(1) writefln("filename = %s", fname);
	
	auto dmd_path = which("dmd");
	debug(1) writefln("dmd_path = %s", dmd_path);
	
	enum dname = "out.deps";
	
	auto dmd_args = ["-deps="~dname, "-o-"] ~ args[1 .. $];
	debug(1) writefln("dmd_args = [%(\"%s\", %)\"]", dmd_args);
	
	//using std.process
	dmd_args = " " ~ dmd_args;	// std.c.process.execvp/spawnvp hack
	auto rc = spawnvp(P_WAIT, dmd_path, dmd_args);	// undocumented
	debug(1) writefln("return code = %s", rc);
	
	load_deps(dname);
	foreach (mod; Module.modules)
	{
		if (mod.recons)
			writefln("recons: %s (%s)", mod.mname, mod.fname);
	}
}

void load_deps(string depsfile)
{
	// deps fileに基点のモジュールは含まれる
	// object.dは依存するモジュールがないからか、あるいはdiだからか、依存先に含まれない
	
	auto f = File(depsfile, "r");
	string ln;
	while (!f.eof && (ln = f.readln().chomp).length > 0)
	{
		string tgtm, tgtf, attr, srcm, srcf;
		
		formattedRead(ln, "%s (%s) : %s : %s (%s)", &tgtm, &tgtf, &attr, &srcm, &srcf);
		
		tgtf = tgtf.replace(`\\`, `\`);
		srcf = srcf.replace(`\\`, `\`);
		auto pub = (attr == "public" ? true : false);
		
		Module.get(tgtm, tgtf).depends(srcm, srcf);
	}
}
