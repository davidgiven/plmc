%{
#include "globals.h"
#include "compiler.h"

static std::unique_ptr<Type> CreateIntegerType(unsigned width);

static std::shared_ptr<Type> boolType = CreateIntegerType(1);
static std::shared_ptr<Type> byteType = CreateIntegerType(8);
static std::shared_ptr<Type> addressType = CreateIntegerType(16);

static std::unique_ptr<Type> CreateIntegerType(unsigned width)
{
	auto t = std::make_unique<Type>();
	t->llvm = llvm::Type::getIntNTy(llvmContext, width);
	t->width = width;
	return t;
}

/* Does any type promotion, if necessary. */
static std::shared_ptr<Node> UnifyTypes(std::shared_ptr<Node>& node, std::shared_ptr<Type>& other)
{
	/* Right is a constant; use the left untouched */

	if (!other)
		return node;

	/* If left is 16-bits wide, leave it like that. */

	if (node->type && (node->type->width == 16))
		return node;

	/* If the left is 1 bit wide, it's a boolean, so convert it to the canonical PL/M
	 * representation before doing anything else. */
	
	if (node->type && (node->type->width == 1))
	{
		auto n = std::make_shared<Node>();
		n->type = other;
		n->value = irbuilder.CreateIntCast(node->value, byteType->llvm, true);
		node = n;
	}

	/* Otherwise, just cast. */

	auto n = std::make_shared<Node>();
	n->type = other;
	n->value = irbuilder.CreateIntCast(node->value, other->llvm, false);
	return n;
}

static llvm::BasicBlock* CreateBlock(const std::string& name)
{
	return llvm::BasicBlock::Create(
		llvmContext, name, GetCurrentProcedure()->procedure->llvm);
}

static std::shared_ptr<Node> CreateConstant(uint16_t value)
{
	auto n = std::make_unique<Node>();
	n->type = nullptr;
	n->value = llvm::Constant::getIntegerValue(
		llvm::Type::getInt16Ty(llvmContext),
		llvm::APInt(16, value));
	return n;
}

%}

%require "3.2"
%language "c++"
%define api.token.raw
%define api.token.constructor
%define api.value.type variant
%define parse.assert
%define api.token.prefix {T_}
%locations
%define parse.trace
%define parse.error detailed

%token IDENT
%token NUMBER
%token STRING

%token ASSIGN 	           ":="
%token COLON  	           ":"
%token COMMA	           ","
%token EQUALS              "="
%token GREATERTHAN         ">"
%token GREATERTHANOREQUALS ">="
%token LESSTHAN            "<"
%token LESSTHANOREQUALS    "<="
%token NOTEQUALS           "<>"
%token SEMI		           ";"
%token OPENPAREN           "("
%token CLOSEPAREN          ")"
%token STAR                "*"
%token SLASH               "/"

%token ADDRESS AND AT BASED BY BYTE CALL CASE
%token CHARINT DATA DECLARE DISABLE DO DWORD
%token ELSE ENABLE END EOF EXTERNAL GO GOTO
%token HALT HWORD IF INITIAL INTEGER INTERRUPT
%token LABEL LITERALLY LONGINT MINUS MOD NOT
%token OFFSET OR PLUS POINTER PROCEDURE PUBLIC
%token REAL REENTRANT RETURN SELECTOR SHORTINT
%token STRUCTURE THEN TO WHILE WORD QWORD XOR

%left ASSIGN
%left STAR SLASH MOD
%left PLUS MINUS
%left EQUALS NOTEQUALS LESSTHAN LESSTHANOREQUALS GREATERTHAN GREATERTHANOREQUALS

%type <std::string> IDENT;
%type <int64_t> NUMBER;
%type <std::string> STRING;
%type <std::shared_ptr<Symbol>> new-ident;
%type <std::shared_ptr<Symbol>> old-ident;

%%

module
	: new-ident COLON 
		{
			module = std::make_unique<llvm::Module>("PL/M Module", llvmContext);
			PushProcedure($1);
			auto* ft = llvm::FunctionType::get(
				llvm::Type::getVoidTy(llvmContext), {}, false);
			$1->procedure->llvm = llvm::Function::Create(
				ft, llvm::Function::ExternalLinkage,
				$1->name, *module);
			irbuilder.SetInsertPoint(
				llvm::BasicBlock::Create(
					llvmContext, "entry", $1->procedure->llvm));
		}
		simple-do-block
		{
			irbuilder.CreateRetVoid();
		}
	;

/* --- Primitives -------------------------------------------------------- */

new-ident
	: IDENT
		{ $$ = scope->add($1); }
	;

old-ident
	: IDENT
		{ $$ = scope->find($1); }
	;

ignored-ident
	: IDENT
	;

simple-do-block
	: DO SEMI 
		{ PushScope(); }
		statements end
		{ PopScope(); }
	;

end
	: END ignored-ident SEMI
	| END SEMI
	;

%type <std::string> label-decl;
label-decl
	: IDENT COLON
		{ $$ = $1; }
	;

/* --- Procedure definitions --------------------------------------------- */

procedure-definition-statement
	: label-decl PROCEDURE 
		{ PushScope(); }
	  optional-procedure-parameters
	  SEMI statements end
	    { PopScope(); }
	;
	
optional-procedure-parameters
    : /* nothing */
	| OPENPAREN parameters CLOSEPAREN
	;

parameters
	: parameter
	| parameters COMMA parameter
	;

parameter
	: new-ident
	;

/* --- Statements -------------------------------------------------------- */

statements
	: /* nothing */
	| statements statement
	;

statement
	: SEMI /* null */
	| variable-declaration-statement
	| procedure-definition-statement
	| label-decl
	| return-statement
	| simple-do-block
	| do-while-statement
	| iterative-while-statement
	| lvalues EQUALS expression SEMI
		{
			for (auto& lvalue : $1)
			{
				auto n = UnifyTypes($3, lvalue->type);
				irbuilder.CreateStore(n->value, lvalue->value);
			}
		}
	;

variable-declaration-statement
	: DECLARE declaration-bodies SEMI
	;

return-statement
	: RETURN SEMI
	| RETURN expression SEMI
	;

%code requires {
	struct DoWhileValues
	{
		llvm::BasicBlock* condBlock;
		llvm::BasicBlock* bodyBlock;
		llvm::BasicBlock* exitBlock;
	};
};

%type <DoWhileValues> do-while-prologue;
do-while-prologue
	: DO WHILE
		{
			$$.condBlock = CreateBlock("while-cond");
			$$.bodyBlock = CreateBlock("while-body");
			$$.exitBlock = CreateBlock("while-exit");
		}
	;

do-while-statement
	: do-while-prologue
		{
			irbuilder.CreateBr($1.condBlock);
			irbuilder.SetInsertPoint($1.condBlock);
		}
		expression SEMI
		{
			irbuilder.CreateCondBr($3->value, $1.bodyBlock, $1.exitBlock);
			PushScope();
			irbuilder.SetInsertPoint($1.bodyBlock);
		}
		statements end
		{
			PopScope();
			irbuilder.CreateBr($1.condBlock);
			irbuilder.SetInsertPoint($1.exitBlock);
		}
	;

%code requires {
	struct IterativeWhileValues
	{
		llvm::BasicBlock* condBlock;
		llvm::BasicBlock* bodyBlock;
		llvm::BasicBlock* exitBlock;
		std::shared_ptr<Node> lvalue;
		std::shared_ptr<Node> initial;
		std::shared_ptr<Node> target;
		std::shared_ptr<Node> stepBy;
	};
};

%type <IterativeWhileValues> iterative-while-prologue;
iterative-while-prologue
	: DO lvalue EQUALS expression TO expression
		optional-by
		{
			$$.condBlock = CreateBlock("do-cond");
			$$.bodyBlock = CreateBlock("do-body");
			$$.exitBlock = CreateBlock("do-exit");
			$$.lvalue = $2;
			$$.initial = UnifyTypes($4, $$.lvalue->type);
			$$.target = UnifyTypes($6, $$.lvalue->type);
			$$.stepBy = UnifyTypes($7, $$.lvalue->type);;
		}
	;

iterative-while-statement
	: iterative-while-prologue SEMI
		{
			irbuilder.CreateStore($1.initial->value, $1.lvalue->value);
			irbuilder.CreateBr($1.condBlock);
			irbuilder.SetInsertPoint($1.condBlock);

			irbuilder.CreateCondBr(
				irbuilder.CreateICmpEQ(
					irbuilder.CreateLoad($1.lvalue->type->llvm, $1.lvalue->value),
					$1.target->value
				),
				$1.bodyBlock,
				$1.exitBlock);
			irbuilder.SetInsertPoint($1.bodyBlock);
			PushScope();
		}
		statements end
		{
			PopScope();
			irbuilder.CreateStore(
				irbuilder.CreateAdd(
					irbuilder.CreateLoad($1.lvalue->type->llvm, $1.lvalue->value),
					$1.stepBy->value
				),
				$1.lvalue->value
			);
			irbuilder.CreateBr($1.condBlock);
			irbuilder.SetInsertPoint($1.exitBlock);
		}
	;

%type <std::shared_ptr<Node>> optional-by;
optional-by
	: /* nothing */
		{ $$ = CreateConstant(1); }
	| BY expression
		{ $$ = $2; }
	;

/* --- Declarations and types -------------------------------------------- */

declaration-bodies
	: declaration-body
	| declaration-bodies COMMA declaration-body
	;

declaration-body
	: new-ident LITERALLY STRING
		{
			$1->literal = std::make_unique<LiteralSymbolData>();
			$1->literal->value = $3;
		}
	| ident-list optional-array-specifier type-specifier 
		{
			for (auto s : $1)
			{
				if (module->getNamedValue(s->name))
					Error("symbol {} is in use", s->name);

				s->variable = std::make_unique<VariableSymbolData>();
				s->variable->llvm = module->getOrInsertGlobal(
					s->name, $3->llvm);
				s->variable->type = $3;
			}
		}
		optional-data
	;

%type <std::vector<std::shared_ptr<Symbol>>> ident-list;
ident-list
	: new-ident
		{ $$ = { $1 }; }
	| OPENPAREN ident-list-inner CLOSEPAREN
		{ $$ = $2; }
	;

%type <std::vector<std::shared_ptr<Symbol>>> ident-list-inner;
ident-list-inner
	: new-ident
		{ $$ = { $1 }; }
	| ident-list-inner COMMA new-ident
		{ $$ = $1; $$.push_back($3); }
	;

%type <std::shared_ptr<Type>> type-specifier;
type-specifier
	: BYTE { $$ = byteType; }
	| ADDRESS { $$ = addressType; }
	;

optional-array-specifier
	: /* nothing */
	| OPENPAREN expression CLOSEPAREN
	;

optional-data
	: /* nothing */
	| DATA OPENPAREN expression CLOSEPAREN
	| INITIAL OPENPAREN expression CLOSEPAREN
	;

/* --- Lvalues ----------------------------------------------------------- */

%type <std::vector<std::shared_ptr<Node>>> lvalues;
lvalues
	: lvalue
		{ $$ = { $1 }; }
	| lvalues COMMA lvalue
		{ $$ = $1; $$.push_back($3); }
	;

%type <std::shared_ptr<Node>> lvalue;
lvalue
	: old-ident
		{
			$$ = std::make_shared<Node>();
			$$->type = $1->variable->type;
			$$->value = $1->variable->llvm;
		}
	;

/* --- Expressions ------------------------------------------------------- */

%code{
	static std::shared_ptr<Node> biarithmetic(
		std::shared_ptr<Node>& left, std::shared_ptr<Node>& right,
			std::function<llvm::Value*(llvm::Value* left, llvm::Value* right)> cb,
			std::shared_ptr<Type> resultType = nullptr)
	{
			auto newleft = UnifyTypes(left, right->type);
			auto newright = UnifyTypes(right, left->type);

			auto n = std::make_unique<Node>();
			n->type = resultType ? resultType : newleft->type;
			n->value = cb(newleft->value, newright->value);
			return n;
	}
};

%type <std::shared_ptr<Node>> expression;
expression
	: OPENPAREN expression CLOSEPAREN
		{ $$ = $2; }
	| NUMBER
		{
			$$ = CreateConstant($1);
		}
	| old-ident
		{
			if (!$1->variable)
				Error("symbol '{}' is not a variable", $1->name);

			$$ = std::make_unique<Node>();
			$$->type = $1->variable->type;
			$$->value = irbuilder.CreateLoad($$->type->llvm, $1->variable->llvm);
		}
	| lvalue ASSIGN expression
		{
			$$ = UnifyTypes($3, $1->type);
			irbuilder.CreateStore($$->value, $1->value);
		}
	| MINUS expression
		{
			$$ = std::make_unique<Node>();
			$$->type = $2->type;
			$$->value = irbuilder.CreateNeg($2->value);
		}
	| expression PLUS expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateAdd(left, right); });
		}
	| expression MINUS expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateSub(left, right); });
		}
	| expression STAR expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateMul(left, right); });
		}
	| expression SLASH expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateUDiv(left, right); });
		}
	| expression MOD expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateURem(left, right); });
		}
	| expression EQUALS expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateICmpEQ(left, right); },
				boolType);
		}
	| expression NOTEQUALS expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateICmpNE(left, right); },
				boolType);
		}
	| expression LESSTHAN expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateICmpULT(left, right); },
				boolType);
		}
	| expression LESSTHANOREQUALS expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateICmpULE(left, right); },
				boolType);
		}
	| expression GREATERTHAN expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateICmpUGT(left, right); },
				boolType);
		}
	| expression GREATERTHANOREQUALS expression
		{
			$$ = biarithmetic($1, $3,
				[&](auto left, auto right) { return irbuilder.CreateICmpUGE(left, right); },
				boolType);
		}
	;
%%

void yy::parser::error(const location& loc, const std::string& message)
{
	Error(message);
}


