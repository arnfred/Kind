## Lexing

Open erlang OTP using `erl`. Then use `leex` to generate `lexer.erl` and the compiler to compile it:

```
leex:file('src/lexer').
> {ok,"src/lexer.erl"}
c('src/lexer').
> {ok,lexer}
```

We can now call the lexer on input using `lexer:string`:

```
lexer:string("def blah 1.3").
> {ok,[{def,1,def},
     {var,1,blah},
     {float,1,1.3}],
    1}
lexer:string("def ?blah").
> {error,{1,lexer,{illegal,"?"}},1}
```

## Parsing

Open erlang OTP using `erl`. Then use `yecc` to generate `parser.erl` and the compiler to compile it:

```
yecc:file('src/parser').
> {ok,"src/parser.erl"}
c('src/parser').
> {ok,parser}
```

Assuming you've also compiled the lexer above, we can parse a string of code:

```
{ok, Tokens, _} = lexer:string("type Boolean = True | False").
parser:parse(Tokens).
> {ok,[{type,1,'Boolean',[{type_symbol,1,'True'}]},
       {type_application,1,'False',[]}]}
```

## Code Generation

Open earlang OTP using `erl`. Then compile the codegen module once you've followed the steps above to compile the lexer and parser:

```
c('src/codegen').
> {ok,codegen}
```

Then you can compile a string to code and execute it:

```
{ok, Tokens, _} = lexer:string("def id a = a").
{ok, Parsed} = parser:parse(Tokens).
{ok, Forms} = codegen:gen({"test", Parsed}).
{ok, Name, Bin} = compile:forms(Forms, [report, verbose, from_core]).
code:load_binary(Name, "test.beam", Bin).
test:id("hello world!").
> "hello world!"
```

To run the unit tests I've included the eunit lib which enables us to run:

```
codegen:test().
```

## Dializer

To type check the src directory, run dializer and see if it's happy:

```
dialyzer --build_plt --apps erts kernel stdlib mnesia compiler
dializer --src src
```

More info here: https://learnyousomeerlang.com/dialyzer
