-module(pattern_gen).
-export([gen_pattern/3]).


% Pattern of shape: prelude/Boolean
% TODO: test with tagged import and type_def with no arguments
% TODO: test with recursive type
gen_pattern(pattern, Scope, {qualified_symbol, Ctx, ModulePath, Name}) ->
    case typecheck:qualified_apply(lenient, Scope, [], Ctx, ModulePath, Name, []) of
        {error, Errs}       -> {error, Errs};
        {ok, {_, Domain}}   -> traverse_domain(Scope, Domain, Ctx)
    end;

% Pattern of shape: module/T(a, b)
gen_pattern(pattern, Scope, {qualified_application, Ctx, ModulePath, Name, Args}) ->
    case error:collect([to_domain(Scope, A) || A <- Args]) of
        {error, Errs}       -> {error, Errs};
        {ok, ArgDomains}    -> 
            case typecheck:qualified_apply(lenient, Scope, [], Ctx, ModulePath, Name, ArgDomains) of
                {error, Errs}       -> {error, Errs};
                {ok, {_, Domain}}   -> traverse_domain(Scope, Domain, Ctx)
            end
    end;

% Pattern of shape: a
gen_pattern(pattern, _, {variable, _, _, _} = Term) -> {ok, [cerl:c_var(symbol:tag(Term))]};

% Pattern of shape: T
gen_pattern(pattern, Scope, {type, Ctx, _, Path} = Term) ->
    Tag = symbol:tag(Term),
    case maps:get(Tag, Scope, undefined) of
        undefined       -> {ok, [cerl:c_atom(Tag)]};
        Form            -> unpack_type(Tag, Form, Scope, Ctx)
    end;

% Key like 'k' in '{k: a}'
gen_pattern(pattern, _, {key, _, _} = Term) -> {ok, [cerl:c_atom(symbol:tag(Term))]};

% Pattern like '{a, k: b}'
gen_pattern(pattern, _, {dict, _, ElemList}) ->
    {ok, [cerl:c_map_pattern(Elems) || 
          Elems <- utils:combinations(ElemList)]};

% Pattern of variable or pair inside product
gen_pattern(pattern, _, {dict_pair, _, Keys, Vals}) ->
    {ok, [cerl:c_map_pair_exact(K, V) || K <- Keys, V <- Vals]};

% Pattern of shape: 'a: T' or 'T {a, B: T}'
% (the latter is a lookup, but get translated to a pair before reaching this
% state of the typegen
gen_pattern(pattern, _, {pair, _, Keys, Vals}) ->
    {ok, [cerl:c_alias(K, V) || K <- Keys, V <- Vals]};

% Pattern of shape: 'T: S'
gen_pattern(pattern, _, {tagged, _, _, Vals} = Term) ->
    Tag = symbol:tag(Term),
    {ok, [cerl:c_tuple([cerl:c_atom(tagged), cerl:c_atom(Tag), V]) || V <- Vals]};

% Pattern of shape: 'A | B'
gen_pattern(pattern, _, {sum, _, ElemList}) ->
    {ok, [E || Elems <- utils:combinations(ElemList), E <- Elems]};

% Pattern of shape: '[1, 2]'
gen_pattern(pattern, _, {list, _, ElemList}) ->
    Ls = [cerl:make_list(Elems) || Elems <- utils:combinations(ElemList)],
    Ts = [cerl:c_tuple(Elems) || Elems <- utils:combinations(ElemList)],
    {ok, Ls ++ Ts};

% Pattern of shape: T where T is recursive
gen_pattern(pattern, _Scope, {recursive_type, Ctx, Name, _}) ->
    {ok, [{variable, Ctx, Name, symbol:id('_')}]};

% Pattern of shape: T(A) where T is recursive
gen_pattern(pattern, _Scope, {recursive_type_application, Ctx, _, _}) ->
    {ok, [{variable, Ctx, '_', symbol:id('_')}]};

% Pattern of shape: T(A)
gen_pattern(pattern, _Scope, {application, Ctx, {type, _, _, _} = T, _}) ->
    error:format({local_type_in_pattern_application, symbol:tag(T)}, {pattern_gen, Ctx});

% Pattern of shape: f(A)
gen_pattern(pattern, _Scope, {application, Ctx, _, _}) ->
    error:format({local_pattern_application}, {pattern_gen, Ctx});

% Pattern of shape: 'T' when 'T' is a type def
gen_pattern(pattern, _, {type_def, Ctx, Name, Expr}) -> 
    case cerl:is_c_fun(Expr) of
        false   -> {ok, Expr};
        true    -> error:format({type_function_in_pattern, Name}, {pattern_gen, Ctx})
    end;

% Pattern of shape: `"string"`, `'atom'` or `3.14`
gen_pattern(pattern, _, {value, _, Type, Val}) -> 
    Bitstr = fun(V) -> cerl:c_bitstr(cerl:abstract(V), cerl:c_atom(undefined), cerl:c_atom(undefined), cerl:c_atom(utf8), cerl:abstract([unsigned, big])) end,
    case Type of
        string  -> {ok, [cerl:c_binary([Bitstr(V) || V <- unicode:characters_to_list(Val, utf8)])]};
        _       -> {ok, [cerl:abstract(Val)]}
    end.

traverse_domain(Scope, Domain, Ctx) -> traverse_term(Scope, utils:domain_to_term(Domain, Ctx)).
traverse_term(Scope, Term) ->  traverse_term(Scope, Term, pattern).
traverse_term(Scope, Term, Type) -> 
    case ast:traverse_term(Type, fun code_gen:pre_gen/3, fun code_gen:gen/3, Scope, Term) of
        {error, Errs}       -> {error, Errs};
        {ok, {_Env, Form}}  -> {ok, Form}
    end.

to_domain(Scope, Term) ->
    case ast:traverse_term(pattern, fun pre_gen_domain/3, fun gen_domain/3, Scope, Term) of
        {error, Errs}       -> {error, Errs};
        {ok, {_Env, Form}}  -> {ok, Form}
    end.

pre_gen_domain(pattern, _, _) -> ok.

% Product domain: { ... }
gen_domain(pattern, _Scope, {dict, _, ElemList}) -> {ok, maps:from_list(ElemList)};
% Product key value pair, `k: v` in `{k: v}`
gen_domain(pattern, _Scope, {dict_pair, _, Key, Val}) -> {ok, {Key, Val}};
% Type refinement: `a: T` (we're only interested in the domain of `T`)
gen_domain(pattern, _Scope, {pair, _, _Key, Val}) -> {ok, Val};
% Type alias
gen_domain(pattern, _Scope, {tagged, _, Tag, Val}) -> {ok, {tagged, Tag, Val}};
% Type sum: `A | B`
gen_domain(pattern, _Scope, {sum, _, ElemList}) -> {ok, {sum, ordsests:from_list(ElemList)}};
% Type list: `[A, B]`
gen_domain(pattern, _Scope, {list, _, ElemList}) -> {ok, {list, ElemList}};
% Qualified symbol: `a/b/T`
gen_domain(pattern, _Scope, {qualified_symbol, Ctx, ModulePath, Name}) ->
    ModuleName = module:beam_name(ModulePath),
    case erlang:function_exported(ModuleName, Name, 0) of
        false   -> error:format({undefined_symbol_in_pattern, ModulePath, Name}, {pattern_gen, Ctx});
        true    -> {ok, erlang:apply(ModuleName, Name, [])}
    end;
% variable
gen_domain(pattern, _Scope, {variable, Ctx, _, _} = Term) -> 
    error:format({variable_in_type_application, symbol:tag(Term)}, {pattern_gen, Ctx});
% Type domain of shape: T
gen_domain(pattern, Scope, {type, _, _, Path} = Term) ->
    Tag = symbol:tag(Term),
    case maps:get(Path, Scope, undefined) of
        undefined       -> {ok, [cerl:c_atom(Tag)]};
        {type, _, _, _} -> {ok, [cerl:c_atom(Tag)]};
        T               -> {ok, T}
    end.

unpack_type(Tag, Fun, Scope,Ctx) ->
    case cerl:is_c_fun(Fun) of
        false   -> error:format({malformed_type_form, Tag, Fun}, {pattern_gen, Ctx});
        true    -> Call = cerl:fun_body(Fun),
                   case cerl:is_c_call(Call) of
                       false    -> error:format({malformed_type_form, Tag, Fun}, {pattern_gen, Ctx});
                       true     -> Arity = cerl:call_arity(Call),
                                   Module = cerl:concrete(cerl:call_module(Call)),
                                   Name = cerl:concrete(cerl:call_name(Call)),
                                   case Arity of
                                       0    -> error:format({malformed_type_form, Tag, Fun}, {pattern_gen, Ctx});
                                       1    -> traverse_domain(Scope, erlang:apply(Module, Name, [lenient]), Ctx);
                                       _    -> error:format({local_type_in_pattern_application, Tag}, {pattern_gen, Ctx})
                                   end
                   end
    end.


