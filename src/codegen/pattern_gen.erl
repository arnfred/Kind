-module(pattern_gen).
-export([gen/1]).

gen(TypesEnv) ->
	fun(pattern, Scope, Term) -> gen_pattern(TypesEnv, Scope, Term) end.

% Pattern of shape: prelude/Boolean
% TODO: test with tagged import and type_def with no arguments
% TODO: test with recursive type
gen_pattern(TypesEnv, Scope, {qualified_type, Ctx, ModulePath, Name}) ->
    ModuleName = module:beam_name(ModulePath),
    case erlang:function_exported(ModuleName, Name, 0) of
        false   -> error:format({undefined_type_in_pattern, Name}, {pattern_gen, Ctx});
        true    -> Domain = erlang:apply(ModuleName, Name, []),
                   traverse_domain(TypesEnv, Scope, utils:domain_to_term(Domain, Ctx))
    end;

% Pattern of shape: a
gen_pattern(_, _, {variable, _, _, _} = Term) -> {ok, [cerl:c_var(symbol:tag(Term))]};

% Pattern of shape: T
gen_pattern(TypesEnv, _, {type, _, _, Path} = Term) ->
    Tag = symbol:tag(Term),
    NewEnv = maps:remove(Tag, TypesEnv), % Avoid recursion for atomic terms
    case maps:get(Path, TypesEnv, undefined) of
        undefined       -> {ok, [cerl:c_atom(Tag)]};
        {type, _, _, _} -> {ok, [cerl:c_atom(Tag)]};
        T               -> traverse_domain(NewEnv, #{}, T)
    end;

% Key like 'k' in '{k: a}'
gen_pattern(_, _, {key, _, _} = Term) -> {ok, [cerl:c_atom(symbol:tag(Term))]};

% Pattern like '{a, k: b}'
gen_pattern(_, _, {dict, _, ElemList}) ->
    {ok, [cerl:c_tuple([cerl:c_atom(product), cerl:c_map_pattern(Elems)]) || 
          Elems <- utils:combinations(ElemList)]};

% Pattern of variable or pair inside product
gen_pattern(_, _, {dict_pair, _, Keys, Vals}) ->
    {ok, [cerl:c_map_pair_exact(K, V) || K <- Keys, V <- Vals]};

% Pattern of shape: 'a: T' or 'T {a, B: T}'
% (the latter is a lookup, but get translated to a pair before reaching this
% state of the typegen
gen_pattern(_, _, {pair, _, Keys, Vals}) ->
    {ok, [cerl:c_alias(K, V) || K <- Keys, V <- Vals]};

% Pattern of shape: 'T: S'
gen_pattern(_, _, {tagged, _, _, Vals} = Term) ->
    Tag = symbol:tag(Term),
    {ok, [cerl:c_tuple([cerl:c_atom(tagged), cerl:c_atom(Tag), V]) || V <- Vals]};

% Pattern of shape: 'A | B'
gen_pattern(_, _, {sum, _, ElemList}) ->
    {ok, [E || Elems <- utils:combinations(ElemList), E <- Elems]};

% Pattern of shape: module/T(a, b)
% TODO: To call arguments we need to compile the arguments from terms to domains
% Simple type T         : symbol:tag(Term)
% Type Fun T()          : Domain of Expr of T's type def
% Type appl m/T(a, b)   : erlang:apply(m, T, [domain(args)])
% Tagged type           : {tagged, Tag, domain(T)}
% Product type (dict)   : {product, #{ ... }}
% Sum type              : {sum, ordsets:from_list([domain(members)])}

% Pattern of shape: 'T' when 'T' is a type def without arguments
gen_pattern(_, _, {type_def, _, _, [], Expr}) -> {ok, Expr};

% Pattern of shape: 'T' when 'T' is a type def with arguments
gen_pattern(_, _, {type_def, Ctx, Name, _Args, _}) -> 
    error:format({type_function_in_pattern, Name}, {pattern_gen, Ctx}).



% TODO: create separate function for generating type fun using the pattern from qualified type
%gen_type_fun(TypesEnv, Scope, {qualified_type, _, ModulePath, Name}, Args) ->

traverse_domain(TypesEnv, Scope, Domain) -> 
    case ast:traverse_term(pattern, fun (_, _, _) -> ok end, gen(TypesEnv), Scope, Domain) of
        {error, Errs}       -> {error, Errs};
        {ok, {_Env, Form}}  -> {ok, Form}
    end.

