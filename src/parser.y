%{
#include "globals.h"
#include "parsecontext.h"

%}

%skeleton "lalr1.cc" // -*- C++ -*-
%require "3.2"
%language "c++"
%define api.token.raw
%define api.token.constructor
%define api.value.type variant
%define parse.assert
%define api.token.prefix {T_}
%param { ParseContext& pc }
%locations
%define parse.trace
%define parse.error detailed
%define parse.lac full

%token IDENT
%token NUMBER
%token STRING

%token ASSIGN 	  ":="
%token COLON  	  ":"
%token SEMI		  ";"
%token COMMA	  ","
%token OPENPAREN  "("
%token CLOSEPAREN ")"

%token ADDRESS AND AT BASED BY BYTE CALL CASE
%token CHARINT DATA DECLARE DISABLE DO DWORD
%token ELSE ENABLE END EOF EXTERNAL GO GOTO
%token HALT HWORD IF INITIAL INTEGER INTERRUPT
%token LABEL LITERALLY LONGINT MINUS MOD NOT
%token OFFSET OR PLUS POINTER PROCEDURE PUBLIC
%token REAL REENTRANT RETURN SELECTOR SHORTINT
%token STRUCTURE THEN TO WHILE WORD QWORD XOR

%type <std::string> IDENT;
%type <long long> NUMBER;
%type <std::string> STRING;
%type <std::shared_ptr<Symbol>> new-ident;
%type <std::shared_ptr<Symbol>> old-ident;

%%

module
	: new-ident COLON simple-do-block
	;

/* --- Primitives -------------------------------------------------------- */

new-ident
	: IDENT
		{ $$ = pc.scope->add($1); }
	;

old-ident
	: IDENT
		{ $$ = pc.scope->find($1); }
	;

label-ident
	: IDENT
	;

ignored-ident
	: IDENT
	;

simple-do-block
	: DO SEMI block end
		{ pc.pushScope(); }
		block end
		{ pc.popScope(); }
	;

end
	: END ignored-ident SEMI
	;

/* --- Program structure ------------------------------------------------- */

block
	: declarations statements
	;

declarations
	: /* nothing */
	| declarations declaration
	;

declaration
	: variable-declaration
	| procedure-definition
	;

variable-declaration
	: DECLARE declaration-bodies SEMI
	;

declaration-bodies
	: declaration-body
	| declaration-bodies COMMA declaration-body
	;

procedure-definition
	: new-ident COLON PROCEDURE 
		{ pc.pushScope(); }
	  optional-procedure-parameters
	  SEMI block end
	    { pc.popScope(); }
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
	| label-ident COLON
	| return-statement
	| simple-do-block
	;

return-statement
	: RETURN SEMI
	| RETURN expression SEMI
	;

/* --- Declarations and types -------------------------------------------- */

declaration-body
	: new-ident LITERALLY STRING
		{
			auto& data = std::get<LiteralSymbolData>($1->data);
			data.value = $3;
		}
	| new-ident type-name optional-data
	;

type-name
	: BYTE
	| WORD
	| ADDRESS
	;

optional-data
	: /* nothing */
	| DATA OPENPAREN expression CLOSEPAREN
	;

/* --- Expressions ------------------------------------------------------- */

expression
	: logical-expression
	| embedded-assignment
	;

embedded-assignment
	: old-ident ASSIGN logical-expression
	;

logical-expression
	: NUMBER
	;

%%

void yy::parser::error(const location& loc, const std::string& message)
{
	Error(message);
}

