%{
#include "globals.h"
#include "parsecontext.h"
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
DIGIT       [0-9]
ID          [A-Za-z_*][A-Za-z0-9_$]*

%x COMMENT
%x STRING

%%
%{
    yy::location& loc = pc.location;
    loc.step ();
%}

{BLANK}+        { loc.step(); }
\n+             { loc.lines (yyleng); loc.step (); }
<<EOF>>         { 
                    yypop_buffer_state();
                    if (!YY_CURRENT_BUFFER)
                        return parser::make_YYEOF(loc);
                }

"/*"            { BEGIN(COMMENT); }
<COMMENT>"*/"   { BEGIN(INITIAL); loc.step(); }
<COMMENT>\n     { }
<COMMENT>.      { }

"\""            { BEGIN(STRING); stringAccumulator = std::stringstream(); }
<STRING>[^"\\]+ { stringAccumulator << yytext; }
<STRING>"\""    { BEGIN(INITIAL); return parser::make_STRING(stringAccumulator.str(), loc); }

{DIGIT}+    {
            printf( "An integer: %s (%d)\n", yytext,
                    atoi( yytext ) );
            }

";"             { return parser::make_SEMI(loc); }
":"             { return parser::make_COLON(loc); }
":="            { return parser::make_ASSIGN(loc); }
","             { return parser::make_COMMA(loc); }
"("             { return parser::make_OPENPAREN(loc); }
")"             { return parser::make_CLOSEPAREN(loc); }

address         { return parser::make_ADDRESS(loc); }
and             { return parser::make_AND(loc); }
at              { return parser::make_AT(loc); }
based           { return parser::make_BASED(loc); }
by              { return parser::make_BY(loc); }
byte            { return parser::make_BYTE(loc); }
call            { return parser::make_CALL(loc); }
case            { return parser::make_CASE(loc); }
charint         { return parser::make_CHARINT(loc); }
data            { return parser::make_DATA(loc); }
declare         { return parser::make_DECLARE(loc); }
disable         { return parser::make_DISABLE(loc); }
do              { return parser::make_DO(loc); }
dword           { return parser::make_DWORD(loc); }
else            { return parser::make_ELSE(loc); }
enable          { return parser::make_ENABLE(loc); }
end             { return parser::make_END(loc); }
eof             { return parser::make_EOF(loc); }
external        { return parser::make_EXTERNAL(loc); }
go              { return parser::make_GO(loc); }
goto            { return parser::make_GOTO(loc); }
halt            { return parser::make_HALT(loc); }
hword           { return parser::make_HWORD(loc); }
if              { return parser::make_IF(loc); }
initial         { return parser::make_INITIAL(loc); }
integer         { return parser::make_INTEGER(loc); }
interrupt       { return parser::make_INTERRUPT(loc); }
label           { return parser::make_LABEL(loc); }
literally       { return parser::make_LITERALLY(loc); }
longint         { return parser::make_LONGINT(loc); }
minus           { return parser::make_MINUS(loc); }
mod             { return parser::make_MOD(loc); }
not             { return parser::make_NOT(loc); }
offset          { return parser::make_OFFSET(loc); }
or              { return parser::make_OR(loc); }
plus            { return parser::make_PLUS(loc); }
pointer         { return parser::make_POINTER(loc); }
procedure       { return parser::make_PROCEDURE(loc); }
public          { return parser::make_PUBLIC(loc); }
real            { return parser::make_REAL(loc); }
reentrant       { return parser::make_REENTRANT(loc); }
return          { return parser::make_RETURN(loc); }
selector        { return parser::make_SELECTOR(loc); }
shortint        { return parser::make_SHORTINT(loc); }
structure       { return parser::make_STRUCTURE(loc); }
then            { return parser::make_THEN(loc); }
to              { return parser::make_TO(loc); }
while           { return parser::make_WHILE(loc); }
word            { return parser::make_WORD(loc); }
qword           { return parser::make_QWORD(loc); }
xor             { return parser::make_XOR(loc); }

{ID}            {
                    auto s = pc.scope->maybeFind(yytext);
                    if (s && s->literal)
                        pc.pushLiteral(s);
                    else
                        return parser::make_IDENT(yytext, loc);
                }
                    
%%

static yy::parser::symbol_type make_NUMBER
    (const std::string &s, const yy::parser::location_type& loc)
{
  errno = 0;
  long n = strtol (s.c_str(), NULL, 10);
  if (! (INT_MIN <= n && n <= INT_MAX && errno != ERANGE))
    throw yy::parser::syntax_error (loc, "integer is out of range: " + s);
  return yy::parser::make_NUMBER ((int) n, loc);
}

Scanner::Scanner(const std::string& filename)
{
    auto* fp = fopen(filename.c_str(), "r");
    yypush_buffer_state(
        yy_create_buffer(fp, YY_BUF_SIZE));
    yy_flex_debug = 1;
}

Scanner::~Scanner()
{
}

void ParseContext::pushLiteral(std::shared_ptr<Symbol>& symbol)
{
    /* yy_scan_string switches to the new buffer, which we don't want. */

    auto currentBuffer = YY_CURRENT_BUFFER;
    auto newBuffer = yy_scan_string(symbol->literal->value.c_str());
    yy_switch_to_buffer(currentBuffer);
    yypush_buffer_state(newBuffer);
}

// vim: sw=4 ts=4 et

