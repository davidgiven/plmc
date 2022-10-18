#include "globals.h"
#include "compiler.h"

int main(int argc, const char* argv[])
{
	Parse(argv[1]);
	llvm::verifyFunction(*GetToplevelProcedure()->procedure->function);
	fmt::print("\nBeginning dump:\n");
	module->dump();
}

