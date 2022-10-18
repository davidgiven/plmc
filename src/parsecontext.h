#pragma once

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/Verifier.h"

class ParseContext;
class Symbol;

#include "parser.tab.h"
#define YY_DECL \
  yy::parser::symbol_type yylex(ParseContext& pc)
YY_DECL;

struct LiteralSymbolData
{
	std::string value;
};

struct ProcedureSymbolData
{
	llvm::Function* function;
};

struct Symbol
{
	Symbol(const std::string& name):
		name(name)
	{}

	const std::string name;
	std::unique_ptr<LiteralSymbolData> literal;
	std::unique_ptr<ProcedureSymbolData> procedure;
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
	void pushLiteral(std::shared_ptr<Symbol>& symbol);

	void pushProcedure(std::shared_ptr<Symbol>& symbol);
	Symbol* getToplevelProcedure();

public:
	yy::location location;
	std::shared_ptr<SymbolTable> scope;
	std::deque<std::shared_ptr<Symbol>> procedures;
	llvm::LLVMContext llvm;
	llvm::IRBuilder<> irbuilder;
	std::unique_ptr<llvm::Module> module;
};

class Scanner
{
public:
	Scanner(const std::string& filename);
	~Scanner();
};

