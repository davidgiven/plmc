#include "globals.h"
#include "parsecontext.h"

int main(int argc, const char* argv[])
{
	ParseContext pc;

	pc.parse(argv[1]);
	llvm::verifyFunction(*pc.getToplevelProcedure()->procedure->function);
	fmt::print("\nBeginning dump:\n");
	pc.module->dump();
}

