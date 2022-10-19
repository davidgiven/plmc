%{
#include "globals.h"
#include "compiler.h"
#include <climits>
#include <sstream>

using yy::parser;

static yy::parser::symbol_type
  make_NUMBER (const std::string &s, const yy::parser::location_type& loc);
static yy::parser::symbol_type popParserState();

#define yyterminate() yy::parser::symbol_type(0, loc)

static std::stringstream stringAccumulator;

%}

%option noyywrap caseless nounput noinput batch debug

BLANK       [ \r\t\f]
ID          [A-Za-z_*][A-Za-z0-9_$]*

%x COMMENT
%x STRING

%%
%{
    location.step ();
%}

{BLANK}+        { location.step(); }
\n+             { location.lines(yyleng); location.step (); }
<<EOF>>         { 
                    yypop_buffer_state();
                    if (!YY_CURRENT_BUFFER)
                        return parser::make_YYEOF(location);
                }

"/*"            { BEGIN(COMMENT); }
<COMMENT>"*/"   { BEGIN(INITIAL); location.step(); }
<COMMENT>\n     { }
<COMMENT>.      { }

"\""            { BEGIN(STRING); stringAccumulator = std::stringstream(); }
<STRING>[^"\\]+ { stringAccumulator << yytext; }
<STRING>"\""    { BEGIN(INITIAL); return parser::make_STRING(stringAccumulator.str(), location); }

[0-9][0-9a-f$]*[boqdh]? { return make_NUMBER(yytext, location); }

"("             { return parser::make_OPENPAREN(location); }
")"             { return parser::make_CLOSEPAREN(location); }
"*"             { return parser::make_STAR(location); }
"+"             { return parser::make_PLUS(location); }
","             { return parser::make_COMMA(location); }
"-"             { return parser::make_MINUS(location); }
"/"             { return parser::make_SLASH(location); }
":"             { return parser::make_COLON(location); }
":="            { return parser::make_ASSIGN(location); }
";"             { return parser::make_SEMI(location); }
"<"             { return parser::make_LESSTHAN(location); }
"<="            { return parser::make_LESSTHANOREQUALS(location); }
"<>"            { return parser::make_NOTEQUALS(location); }
"="             { return parser::make_EQUALS(location); }
">"             { return parser::make_GREATERTHAN(location); }
">="            { return parser::make_GREATERTHANOREQUALS(location); }

address         { return parser::make_ADDRESS(location); }
and             { return parser::make_AND(location); }
at              { return parser::make_AT(location); }
based           { return parser::make_BASED(location); }
by              { return parser::make_BY(location); }
byte            { return parser::make_BYTE(location); }
call            { return parser::make_CALL(location); }
case            { return parser::make_CASE(location); }
charint         { return parser::make_CHARINT(location); }
data            { return parser::make_DATA(location); }
declare         { return parser::make_DECLARE(location); }
disable         { return parser::make_DISABLE(location); }
do              { return parser::make_DO(location); }
dword           { return parser::make_DWORD(location); }
else            { return parser::make_ELSE(location); }
enable          { return parser::make_ENABLE(location); }
end             { return parser::make_END(location); }
eof             { return parser::make_EOF(location); }
external        { return parser::make_EXTERNAL(location); }
go              { return parser::make_GO(location); }
goto            { return parser::make_GOTO(location); }
halt            { return parser::make_HALT(location); }
hword           { return parser::make_HWORD(location); }
if              { return parser::make_IF(location); }
initial         { return parser::make_INITIAL(location); }
integer         { return parser::make_INTEGER(location); }
interrupt       { return parser::make_INTERRUPT(location); }
label           { return parser::make_LABEL(location); }
literally       { return parser::make_LITERALLY(location); }
longint         { return parser::make_LONGINT(location); }
minus           { return parser::make_MINUS(location); }
mod             { return parser::make_MOD(location); }
not             { return parser::make_NOT(location); }
offset          { return parser::make_OFFSET(location); }
or              { return parser::make_OR(location); }
plus            { return parser::make_PLUS(location); }
pointer         { return parser::make_POINTER(location); }
procedure       { return parser::make_PROCEDURE(location); }
public          { return parser::make_PUBLIC(location); }
real            { return parser::make_REAL(location); }
reentrant       { return parser::make_REENTRANT(location); }
return          { return parser::make_RETURN(location); }
selector        { return parser::make_SELECTOR(location); }
shortint        { return parser::make_SHORTINT(location); }
structure       { return parser::make_STRUCTURE(location); }
then            { return parser::make_THEN(location); }
to              { return parser::make_TO(location); }
while           { return parser::make_WHILE(location); }
word            { return parser::make_WORD(location); }
qword           { return parser::make_QWORD(location); }
xor             { return parser::make_XOR(location); }

{ID}            {
                    auto s = scope->maybeFind(yytext);
                    if (s && s->literal)
                        PushLiteral(s);
                    else
                        return parser::make_IDENT(yytext, location);
                }
                    
.               { Error("unparseable character '{}'", yytext); }
%%

static yy::parser::symbol_type make_NUMBER
    (const std::string &s, const yy::parser::location_type& loc)
{
    errno = 0;
    long n = strtol(s.c_str(), NULL, 10);
    if (!(INT_MIN <= n && n <= INT_MAX && errno != ERANGE))
        throw yy::parser::syntax_error (loc, "integer is out of range: " + s);
    return yy::parser::make_NUMBER((int) n, loc);
}

void IncludeFile(const std::string& filename)
{
    location.initialize(&filename);

    auto* fp = fopen(filename.c_str(), "r");
    yypush_buffer_state(
        yy_create_buffer(fp, YY_BUF_SIZE));
    yy_flex_debug = 1;
}

void PushLiteral(std::shared_ptr<Symbol>& symbol)
{
    /* yy_scan_string switches to the new buffer, which we don't want. */

    auto currentBuffer = YY_CURRENT_BUFFER;
    auto newBuffer = yy_scan_string(symbol->literal->value.c_str());
    yy_switch_to_buffer(currentBuffer);
    yypush_buffer_state(newBuffer);
}

// vim: sw=4 ts=4 et

