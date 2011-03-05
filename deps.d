import std.string;
import std.format;
import std.stdio;
import std.algorithm;
import std.array;

import hash;

version (none)
{
	struct Mod
	{
		string m, f; 
		
		// すべて定義しないとAssociative Arrayで使えない
		bool opEquals(ref const Mod mod) const
		{
			return mod.m == m && mod.f == f;
		}
		// ditto
		int opCmp(ref const Mod mod) const
		{
			if (auto diff = std.string.cmp(mod.m, m))
				return diff;
			else
				return std.string.cmp(mod.f, f);
		}
		// ditto
		hash_t toHash() const
		{
			return typeid(m).getHash(&m) ^ typeid(f).getHash(&f);
		}
	}
}
else
{
	struct ModImpl
	{
		string m, f; 
	}
	alias Hashable!ModImpl Mod;
}

void main(string[] args)
{
	if (args.length != 2)
	{
	/+	auto m1 = Mod("test", "test.d");
		auto m2 = Mod("test", "test.d");
		writefln("%s", m1.toHash);
		writefln("%s", m2.toHash);+/
		
		writefln("%s", "aaa" >  "aab");
		writefln("%s", "aaa" >= "aab");
		writefln("%s", "aaa" == "aab");
		writefln("%s", "aaa" <= "aab");
		writefln("%s", "aaa" <  "aab");
		return;
	}
	
	auto fname = args[1];
	auto f = File(fname, "r");
	
	bool[Mod][Mod] deps;
	
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