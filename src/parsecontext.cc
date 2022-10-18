#include "globals.h"
#include "parsecontext.h"
#include <stdio.h>

SymbolTable::SymbolTable(std::shared_ptr<SymbolTable> next): _next(next) {}

std::shared_ptr<SymbolTable> SymbolTable::getNextScope()
{
    return _next;
}

ParseContext::ParseContext():
	irbuilder(llvm)
{
	scope = std::make_shared<SymbolTable>();
	module = std::make_unique<llvm::Module>("PL/M Module", llvm);
}

void ParseContext::parse(const std::string& filename)
{
    location.initialize(&filename);

    Scanner scanner(filename);
    yy::parser parse(*this);
    parse.set_debug_level(1);
    int res = parse();
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

void ParseContext::pushScope()
{
	scope = std::make_shared<SymbolTable>(scope);
}

void ParseContext::popScope()
{
    scope = scope->getNextScope();
}

void ParseContext::pushProcedure(std::shared_ptr<Symbol>& symbol)
{
	symbol->procedure = std::make_unique<ProcedureSymbolData>();
	procedures.push_back(symbol);
}

Symbol* ParseContext::getToplevelProcedure()
{
	return procedures.front().get();
}

