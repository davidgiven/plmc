#include "globals.h"
#include "compiler.h"
#include <stdio.h>

yy::location location;
std::shared_ptr<SymbolTable> scope = std::make_shared<SymbolTable>();
std::deque<std::shared_ptr<Symbol>> procedures;
llvm::LLVMContext llvmContext;
llvm::IRBuilder<> irbuilder(llvmContext);
std::unique_ptr<llvm::Module> module;

SymbolTable::SymbolTable(std::shared_ptr<SymbolTable> next): _next(next) {}

std::shared_ptr<SymbolTable> SymbolTable::getNextScope()
{
    return _next;
}

std::shared_ptr<Symbol> SymbolTable::add(const std::string& name)
{
	auto it = _symbols.find(name);
	if (it != _symbols.end())
		Error("symbol {} already declared", name);
	
	auto s = std::make_shared<Symbol>(name);
	_symbols[name] = s;
	return s;
}

std::shared_ptr<Symbol> SymbolTable::maybeFind(const std::string& name)
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

std::shared_ptr<Symbol> SymbolTable::find(const std::string& name)
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
	scope = std::make_shared<SymbolTable>(scope);
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

