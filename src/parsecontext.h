#pragma once

class ParseContext;
class Symbol;

#include "parser.tab.h"
#define YY_DECL \
  yy::parser::symbol_type yylex(ParseContext& pc)
YY_DECL;

class LiteralSymbolData
{
public:
	std::string value;
};

class Symbol
{
public:
	Symbol(const std::string& name):
		name(name)
	{}

public:
	const std::string name;
	std::variant<LiteralSymbolData> data;
};

class SymbolTable
{
public:
	SymbolTable(std::shared_ptr<SymbolTable> next = nullptr);

	std::shared_ptr<SymbolTable> getNextScope();

	std::shared_ptr<Symbol> add(const std::string& name);
	std::shared_ptr<Symbol> maybeFind(const std::string& name);
	std::shared_ptr<Symbol> find(const std::string& name);

private:
	std::map<std::string, std::shared_ptr<Symbol>> _symbols;
	std::shared_ptr<SymbolTable> _next;
};

class ParseContext
{
public:
	ParseContext();

public:
	void parse(const std::string& filename);

	void startScanning(const std::string& filename);
	void stopScanning();

	void pushScope();
	void popScope();
	bool pushLiteral(std::shared_ptr<Symbol>& symbol);

public:
	yy::location location;
	std::shared_ptr<SymbolTable> scope;
};

class Scanner
{
public:
	Scanner(const std::string& filename);
	~Scanner();
};

