import std.string;
import std.format;
import std.stdio;
import std.algorithm;
import std.array;

import xtk.hash;
import xtk.filesys;

import std.typecons;
alias Hashable!(Tuple!(string, "m", string, "f")) Mod;

void main(string[] args)
{
	auto fname = args[1];
	
	auto dmd_path = which("dmd");
	writefln("dmd_path = %s", dmd_path);
	
	
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
