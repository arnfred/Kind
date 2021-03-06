-module(symbol).
-export([id/1, tag/1, name/1, is/1, ctx/1, rename/2, path/1]).

id(Path) when is_list(Path) -> 
    PathString = [atom_to_list(A) || A <- lists:join('_', Path)],
    list_to_atom(lists:flatten([PathString, "_", get_random_string(6)]));
id(Symbol) -> id([Symbol]).

tag(Symbols) when is_list(Symbols) ->
    list_to_atom(lists:flatten([atom_to_list(A) || A <- lists:join('/', Symbols)]));
tag({def, _, Name, _}) -> Name;
tag({recursive_type, _, _, Symbols}) -> tag(Symbols);
tag({tagged, _, Symbols, _}) -> tag(Symbols);
tag({symbol, _, _, S}) -> S;
tag({variable, _, _, Tag}) -> Tag;
tag({keyword, _, Path, Name}) -> tag(Path ++ [Name]);
tag({keyword, _, K}) -> K;
tag({qualified_symbol, _, Path, S}) -> tag(Path ++ [S]);
tag({beam_symbol, _, Path, S}) -> tag(Path ++ [S]);
tag(Term) -> list_to_atom("expr_" ++ integer_to_list(erlang:phash2(Term))).

path(Tag) when is_atom(Tag) -> 
    lists:map(fun(C) -> list_to_atom(C) end, re:split(atom_to_list(Tag), "/", [{return,list}]));
path(Term) -> path(tag(Term)).

ctx(Term) -> element(2, Term).

name({pair, _, K, _}) -> name(K);
name({dict_pair, _, K, _}) -> name(K);
name({symbol, _, _, S}) -> S;
name({link, _, Term}) -> name(Term);
name({qualified_symbol, _, _, S}) -> S;
name({qualified_symbol, _, S}) -> S;
name({beam_symbol, _, _, S}) -> S;
name({tagged, _, Symbols, _}) -> lists:last(Symbols);
name({variable, _, Key, _}) -> Key;
name({keyword, _, Key}) -> Key;
name({keyword, _, _, Key}) -> Key.

rename({pair, Ctx, K, V}, Name) -> {pair, Ctx, rename(K, Name), V};
rename({dict_pair, Ctx, K, V}, Name) -> {dict_pair, Ctx, rename(K, Name), V};
rename({key, Ctx, _}, Name) -> {key, Ctx, Name};
rename({symbol, Ctx, Path, _}, Name) -> {symbol, Ctx, Path, Name};
rename({link, Ctx, Term}, Name) -> {link, Ctx, rename(Term, Name)};
rename({qualified_symbol, Ctx, Path, _}, Name) -> {qualified_symbol, Ctx, Path, Name};
rename({beam_symbol, Ctx, Path, _}, Name) -> {beam_symbol, Ctx, Path, Name};
rename({qualified_symbol, Ctx, _}, Name) -> {qualified_symbol, Ctx, Name};
rename({tagged, Ctx, Symbols, Expr}, Name) -> {tagged, Ctx, lists:droplast(Symbols) ++ [Name], Expr};
rename({variable, Ctx, _, Tag}, Name) -> {variable, Ctx, Name, Tag}.


is({symbol, _, _, _})           -> true;
is({variable, _, _, _})         -> true;
is({qualified_symbol, _, _, _}) -> true;
is({beam_symbol, _, _, _})      -> true;
is({qualified_symbol, _, _})    -> true;
is(_)                           -> false.

get_random_string(Length) ->
    AllowedChars = "abcdefghijklmnopqrstuvwxyz1234567890",
    F = fun(_, Acc) -> 
        Char = lists:nth(rand:uniform(length(AllowedChars)), AllowedChars),
        [Char] ++ Acc
    end,
    lists:foldl(F, [], lists:seq(1, Length)).
