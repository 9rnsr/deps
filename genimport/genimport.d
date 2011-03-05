template Import(string name)
{
	mixin("import "~name~";");
}

void main()
{
	Import!("std.stdio").writefln("");
}
