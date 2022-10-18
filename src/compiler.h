#pragma once

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/Verifier.h"

class Symbol;

#include "parser.tab.h"
#define YY_DECL yy::parser::symbol_type yylex()
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
    Symbol(const std::string& name): name(name) {}

    const std::string name;
    std::unique_ptr<LiteralSymbolData> literal;
    std::unique_ptr<ProcedureSymbolData> procedure;
};

class Scope
{
public:
    Scope(std::shared_ptr<Scope> next = nullptr);

    std::shared_ptr<Scope> getNextScope();

    std::shared_ptr<Symbol> add(const std::string& name);
    std::shared_ptr<Symbol> maybeFind(const std::string& name);
    std::shared_ptr<Symbol> find(const std::string& name);

private:
    std::map<std::string, std::shared_ptr<Symbol>> _symbols;
    std::shared_ptr<Scope> _next;
};

extern void Parse(const std::string& filename);
extern void IncludeFile(const std::string& filename);
extern void StartScanning(const std::string& filename);
extern void StopScanning();
extern void PushScope();
extern void PopScope();
extern void PushLiteral(std::shared_ptr<Symbol>& symbol);
extern void PushProcedure(std::shared_ptr<Symbol>& symbol);
extern Symbol* GetToplevelProcedure();

extern yy::location location;
extern std::shared_ptr<Scope> scope;
extern std::deque<std::shared_ptr<Symbol>> procedures;
extern llvm::LLVMContext llvmContext;
extern llvm::IRBuilder<> irbuilder;
extern std::unique_ptr<llvm::Module> module;
