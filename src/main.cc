#include "globals.h"
#include "compiler.h"
#include <llvm/Support/raw_os_ostream.h>

int main(int argc, const char* argv[])
{
	Parse(argv[1]);
	llvm::verifyFunction(*GetToplevelProcedure()->procedure->llvm);
	llvm::raw_os_ostream os(std::cout);
	module->print(os, nullptr);
}

