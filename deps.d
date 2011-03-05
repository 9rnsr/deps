import std.string;
import std.format;
import std.stdio;
import std.algorithm;
import std.array;

import xtk.hash;
import xtk.filesys;

import std.typecons;

debug = PrintDeps;

string curdir;
string objdir;
string dmd_path;
string scini_path;
string deps_name = "out.deps";

string[] exclude_dirs;


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
		mname = m;
		
		fname = f;
		oname = std.path.join(
			(objdir ? objdir : curdir), f.basename.setExt("obj"));
		ftime = timeLastModified(f);
		otime = timeLastModified(oname, SysTime.min);
		
		exclude = excludeCheck(fname);
		
		if (!exclude && otime < ftime)
		{
			recons = true;
			
			debug(PrintDeps) writefln("object depend");
			debug(PrintDeps) writefln("module = %s", m);
			debug(PrintDeps) writefln("     f = %s (%s)", ftime, fname);
			debug(PrintDeps) writefln("     o = %s (%s)", otime, oname);
		}
	}
	
	void depends(string srcm, string srcf)
	{
		auto src = Module.get(srcm , srcf);
		src.targets[this] = true;
		
		if (src !in sources)
		{
			sources[src] = true;	// set
		}
	}
	
	string mname;
	string  fname, oname;
	SysTime ftime, otime;
	
	bool recons;
	bool exclude;
	
	bool[Module] sources;	// set
	bool[Module] targets;	// set
	
	
	static bool excludeCheck(string path)
	{
		auto path_ = path.tolower;
		
		foreach (dir; exclude_dirs)
		{
			auto dir_ = dir.tolower();
			
			if (path_.length >= dir_.length && path_[0 .. dir_.length] == dir_)
				return true;
		}
		return false;
	}
	
	static void resolve()
	{
		//stdなどをrecons=trueの群から除外する
		
		// src->targetへreconsを感染させる
		size_t cnt;
		do{
			cnt = 0;
			foreach (src; modules)
			{
				if (src.exclude) continue;
				if (!src.recons) continue;
				
				foreach (tgt, __dummy; src.targets)
				{
					if (!tgt.recons)
					{
						tgt.recons = true, ++cnt;
						debug(PrintDeps) writefln("source depend");
						debug(PrintDeps) writefln("module = %s", tgt.mname);
						debug(PrintDeps) writefln("   src = %s (%s)", src.ftime, src.fname);
						debug(PrintDeps) writefln("   tgt = %s (%s)", tgt.ftime, tgt.fname);
					}
				}
			}
		}while (cnt > 0)
	}
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
	
	// parsing arguments
	string[] impdir;
	getopt(args,
		std.getopt.config.passThrough,
		"|od",	&objdir,
		"|I", delegate(string opt, string val){
			impdir ~= val;
		}
	);

	// get environments
	curdir = std.file.getcwd();
	writefln("curdir = %s, objdir = %s", curdir, objdir.rel2abs);
	
	dmd_path = where_dmd();
	scini_path = where_scini();
	debug(1) writefln("dmd    path = %s", dmd_path);
	debug(1) writefln("sc.ini path = %s", scini_path);

	auto dmd2dir = dmd_path.dirname.chompPath().chompPath();	// chomp (windows\bin)
	exclude_dirs = [
		joinPath(dmd2dir, `src\phobos`),
		joinPath(dmd2dir, `src\druntime`),
		joinPath(dmd2dir, `user\src\`)];
	debug(1) writefln("dmd2dir = %s", dmd2dir);
	debug(1) writefln("exclude_dirs = %s", exclude_dirs);

	auto fname = args[1];
	debug(1) writefln("filename = %s", fname);
	
	string[] import_args;
	if (impdir.length > 0)
	{
		foreach (dir; impdir)
			import_args ~= "-I"~dir;
	}

	{
		auto dmd_args = args[1 .. $] ~ ["-deps="~deps_name, "-o-"] ~ import_args;
		debug(1) writefln("dmd_args = [%(\"%s\", %)\"]", dmd_args);
		
		//using std.process
		dmd_args = " " ~ dmd_args;	// std.c.process.execvp/spawnvp hack
		auto rc = spawnvp(P_WAIT, dmd_path, dmd_args);	// undocumented
		debug(1) writefln("return code = %s", rc);
		if (rc != 0) return;
	}
	
	load_deps(deps_name);
	Module.resolve();
	
/+	string[] build_args;
	foreach (mod; Module.modules)
	{
		if (mod.recons)
			writefln("recons: %s (%s)", mod.mname, mod.fname);
		
		if (mod.recons)
			build_args ~= mod.fname;
		else if (!mod.exclude)
			build_args ~= mod.oname;
	}
	
	writefln("%s", build_args);
	{
		auto dmd_args = build_args ~ import_args;
		if (objdir)
			dmd_args ~= "-od"~objdir;
		dmd_args ~= "-of"~fname.setExt("exe");
		debug(1) writefln("dmd_args = [%(\"%s\", %)\"]", dmd_args);
		
		dmd_args = " " ~ dmd_args;	// std.c.process.execvp/spawnvp hack
		auto rc = spawnvp(P_WAIT, dmd_path, dmd_args);	// undocumented
		debug(1) writefln("return code = %s", rc);
		if (rc != 0) return;
	}+/

	{
		string[] build_args;
		
		auto opt_args = import_args;
		if (objdir)
			opt_args ~= "-od"~objdir;

		foreach (mod; Module.modules)
		{
			if (mod.recons)
				writefln("recons: %s (%s)", mod.mname, mod.fname);
			
			if (mod.recons)
			{
				auto dmd_args = [" ", mod.fname] ~ opt_args ~ "-c";
				debug(1) writefln("dmd_args = [%(\"%s\", %)\"]", dmd_args);
				auto rc = spawnvp(P_WAIT, dmd_path, dmd_args);	// undocumented
			}
			
			if (!mod.exclude)
				build_args ~= mod.oname;
		}
		
		{
			auto dmd_args = " " ~ build_args ~ opt_args ~ ("-of"~fname.setExt("exe"));
			debug(1) writefln("dmd_args = [%(\"%s\", %)\"]", dmd_args);
			auto rc = spawnvp(P_WAIT, dmd_path, dmd_args);	// undocumented
			debug(1) writefln("return code = %s", rc);
		}
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

string where_dmd()
{
	return which("dmd");
}

string where_scini()
{
	auto home = environment["HOME"];
	if (home.length)
		return which("sc.ini", [`.\`, home, dmd_path.dirname]);
	else
		return which("sc.ini", [`.\`, dmd_path.dirname]);
}
