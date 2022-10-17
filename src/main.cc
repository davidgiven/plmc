#include "globals.h"
#include "parsecontext.h"

int main(int argc, const char* argv[])
{
	ParseContext pc;

	pc.parse(argv[1]);
}

