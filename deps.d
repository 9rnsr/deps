import std.string;
import std.format;
import std.stdio;
import std.algorithm;
import std.array;

import xtk.hash;
import xtk.filesys;

import std.typecons;
alias Hashable!(Tuple!(string, "m", string, "f")) Mod;

import std.process;

void main(string[] args)
{
	if (args.length == 1)
	{
		writefln("usage : deps");
		return;
	}
	
	auto fname = args[1];
	writefln("filename = %s", fname);
	
	auto dmd_path = which("dmd");
	writefln("dmd_path = %s", dmd_path);
	
	auto dmd_args = ["-deps=out.deps", "-o-"] ~ args[1 .. $];
	writefln("dmd_args = [%(\"%s\", %)\"]", dmd_args);
	
	//using std.process
	dmd_args = " " ~ dmd_args;	// std.c.process.execvp/spawnvp hack
	auto rc = spawnvp(P_WAIT, dmd_path, dmd_args);	// undocumented
	writefln("return code = %s", rc);
	
	bool[Mod][Mod] deps;
	//load_deps(fname, deps);
}

void load_deps(string fname, ref bool[Mod][Mod] deps)
{
	// deps fileに基点のモジュールは含まれる
	
	auto f = File(fname, "r");
	string ln;
	while (!f.eof && (ln = f.readln().chomp).length > 0)
	{
		string tgtm, tgtf, attr, srcm, srcf;
		
		formattedRead(ln, "%s (%s) : %s : %s (%s)", &tgtm, &tgtf, &attr, &srcm, &srcf);
		
		tgtf = tgtf.replace(`\\`, `\`);
		srcf = srcf.replace(`\\`, `\`);
		auto pub = (attr == "public" ? true : false);
		
		auto tgt = Mod(tgtm, tgtf);
		if (auto src = tgt in deps)
		{
			(*src)[Mod(srcm, srcf)] = pub;
		}
		else
			deps[tgt] = [Mod(srcm, srcf) : pub];
	}
	
	foreach (tgt, srclst; deps)
	{
		writefln("%s (%s)", tgt.m, tgt.f);
		foreach (src, pub; srclst)
		{
		//	writefln("%s [%s] / %s / %s [%s]", tgt.m, tgt.f, pub, src.m, src.f);
		//	writefln("%s (%s) : %s : %s (%s)", tgt.m, tgt.f, pub, src.m, src.f);
			writefln("\t%s : %s (%s)", pub?"public ":"private", src.m, src.f);
		}
	}
}
