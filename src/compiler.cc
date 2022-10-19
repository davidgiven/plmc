#include "globals.h"
#include "compiler.h"
#include <stdio.h>

yy::location location;
std::shared_ptr<Scope> scope = std::make_shared<Scope>();
llvm::LLVMContext llvmContext;
std::unique_ptr<llvm::Module> module;
llvm::IRBuilder<> irbuilder(llvmContext);

static std::deque<std::shared_ptr<Symbol>> procedures;

Scope::Scope(std::shared_ptr<Scope> next): _next(next) {}

std::shared_ptr<Scope> Scope::getNextScope()
{
    return _next;
}

std::shared_ptr<Symbol> Scope::add(const std::string& name)
{
	auto it = _symbols.find(name);
	if (it != _symbols.end())
		Error("symbol {} already declared", name);
	
	auto s = std::make_shared<Symbol>(name);
	_symbols[name] = s;
	return s;
}

std::shared_ptr<Symbol> Scope::maybeFind(const std::string& name)
{
	auto it = _symbols.find(name);
	if (it == _symbols.end())
	{
		if (_next)
			return _next->maybeFind(name);
		return nullptr;
	}
	return it->second;
}

std::shared_ptr<Symbol> Scope::find(const std::string& name)
{
	auto s = maybeFind(name);
	if (!s)
		Error("symbol {} not found", name);
	return s;
}

void Parse(const std::string& filename)
{
	IncludeFile(filename);
    yy::parser parser;
    parser.set_debug_level(1);
    int res = parser();
}

void PushScope()
{
	scope = std::make_shared<Scope>(scope);
}

void PopScope()
{
    scope = scope->getNextScope();
}

void PushProcedure(std::shared_ptr<Symbol>& symbol)
{
	symbol->procedure = std::make_unique<ProcedureSymbolData>();
	procedures.push_back(symbol);
}

Symbol* GetToplevelProcedure()
{
	return procedures.front().get();
}

Symbol* GetCurrentProcedure()
{
	return procedures.back().get();
}

