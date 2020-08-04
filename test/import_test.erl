-module(import_test).

-include_lib("eunit/include/eunit.hrl").
-include("src/error.hrl").

test_import(Symbols, SourceMap) -> 
    import:import({import, #{}, [{symbol, #{}, variable, S} || S <- Symbols]}, SourceMap, #{}).

test_import(Symbols, Mappings, SourceMap) -> test_import(Symbols, Mappings, SourceMap, #{}).

test_import(Symbols, Mappings, SourceMap, LocalTypes) -> 
    F = fun({Name, Name}) -> {symbol, #{}, variable, Name};
           ({Alias, Name}) -> {pair, #{}, {symbol, #{}, variable, Alias}, {symbol, #{}, variable, Name}} end,
    Module = [{symbol, #{}, variable, S} || S <- Symbols],
    Path = Module ++ [{dict, #{}, [F(Elem) || Elem <- maps:to_list(Mappings)]}],
    import:import({import, #{}, Path}, SourceMap, LocalTypes).

erlang_import_test() ->
    Actual = test_import([erlang, atom_to_list], #{}),
    ?assertMatch({ok, [{alias, _, atom_to_list, {qualified_variable, _, [erlang], atom_to_list}}]}, Actual).

erlang_module_import_test() ->
    Actual = test_import([lists, reverse], #{}),
    ?assertMatch({ok, [{alias, _, reverse, {qualified_variable, _, [lists], reverse}}]}, Actual).

source_import_test() ->
    SourceMap = #{module_name => {module, #{}, [module_name], #{test_fun => blup}}},
    Actual = test_import([module_name, test_fun], SourceMap),
    ?assertMatch({ok, [{alias, _, test_fun, {qualified_variable, _, [module_name], test_fun}}]}, Actual).

beam_wildcard_test() ->
    Actual = test_import([random, '_'], #{}),
    ?assertMatch({ok, [{alias, _, seed0, {qualified_variable, _, [random], seed0}},
                       {alias, _, seed, {qualified_variable, _, [random], seed}},
                       {alias, _, uniform, {qualified_variable, _, [random], uniform}},
                       {alias, _, uniform_s, {qualified_variable, _, [random], uniform_s}}]}, Actual).

source_wildcard_test() ->
    SourceMap = #{blap => {module, #{}, [blap], #{fun1 => blip,
                                                      fun2 => blop,
                                                      fun3 => blup}}},
    Actual = test_import([blap, '_'], SourceMap),
    ?assertMatch({ok, [{alias, _, fun1, {qualified_variable, _, [blap], fun1}},
                       {alias, _, fun2, {qualified_variable, _, [blap], fun2}},
                       {alias, _, fun3, {qualified_variable, _, [blap], fun3}}]}, Actual).

beam_dict_test() ->
    Actual = test_import([random], #{seed => glunk, uniform => uniform}, #{}),
    ?assertMatch({ok, [{alias, _, glunk, {qualified_variable, _, [random], seed}},
                       {alias, _, uniform, {qualified_variable, _, [random], uniform}}]}, Actual).

source_dict_test() ->
    SourceMap = #{blap => {module, #{}, [blap], #{fun1 => blip,
                                                      fun2 => blop,
                                                      fun3 => blup}}},
    Actual = test_import([blap], #{fun1 => blarg, fun2 => fun2}, SourceMap),
    ?assertMatch({ok, [{alias, _, blarg, {qualified_variable, _, [blap], fun1}},
                       {alias, _, fun2, {qualified_variable, _, [blap], fun2}}]}, Actual).

module_type_test() ->
    SourceMap = #{blap_Blup => {module, #{}, ['blap', 'Blup'], #{'A' => 'A'}}},
    Path = [{symbol, #{}, variable, blap}, {symbol, #{}, type, 'Blup'}, {symbol, #{}, type, 'A'}],
    Actual = import:import({import, #{}, Path}, SourceMap, #{}),
    ?assertMatch({ok, [{alias, _, 'A', {qualified_type, _, ['blap', 'Blup'], 'A'}}]}, Actual).

wildcard_type_test() ->
    SourceMap = #{blap_Blup => {module, #{}, [blap, 'Blup'], #{'A' => 'A', 'B' => 'B'}}},
    Path = [{symbol, #{}, variable, blap}, {symbol, #{}, type, 'Blup'}, {symbol, #{}, variable, '_'}],
    Actual = import:import({import, #{}, Path}, SourceMap, #{}),
    ?assertMatch({ok, [{alias, _, 'A', {qualified_type, _, ['blap', 'Blup'], 'A'}},
                       {alias, _, 'B', {qualified_type, _, ['blap', 'Blup'], 'B'}}]}, Actual).

local_type_test() ->
    Path = [{symbol, #{}, type, 'Blup'}, {symbol, #{}, variable, '_'}],
    Actual = import:import({import, #{}, Path}, #{}, #{'Blup' => ['A', 'B', 'C']}),
    ?assertMatch({ok, [{alias, _, 'A', {type, _, 'A', ['Blup', 'A']}},
                       {alias, _, 'B', {type, _, 'B', ['Blup', 'B']}},
                       {alias, _, 'C', {type, _, 'C', ['Blup', 'C']}}]}, Actual).

local_type_underscore_test() ->
    Path = [{symbol, #{}, type, 'Blup'}, {symbol, #{}, type, 'A'}],
    Actual = import:import({import, #{}, Path}, #{}, #{'Blup' => ['A', 'B', 'C']}),
    ?assertMatch({ok, [{alias, _, 'A', {type, _, 'A', ['Blup', 'A']}}]}, Actual).

errors_test_() ->
    SourceMap = #{blap => {module, #{}, [blap], #{'Blup' => blip}}},
    [?_errorMatch({empty_import},
                  import:import({import, #{}, []}, #{}, #{})),
     ?_errorMatch({import_underscore_for_alias, blah},
                  test_import(['blap'], #{blah => '_'}, SourceMap)),
     ?_errorMatch({import_underscore_for_name, blah},
                  test_import(['blap'], #{'_' => blah}, SourceMap)),
     ?_errorMatch({import_def_alias_for_type, a, 'A'},
                  import:import({import, #{}, [{symbol, #{}, variable, blap},
                                        {dict, #{}, [{pair, #{},
                                                      {symbol, #{}, type, 'A'},
                                                      {symbol, #{}, variable, a}}]}]}, #{}, #{})),
     ?_errorMatch({import_type_alias_for_def, 'A', a},
                  import:import({import, #{}, [{symbol, #{}, variable, blap},
                                        {dict, #{}, [{pair, #{},
                                                      {symbol, #{}, variable, a},
                                                      {symbol, #{}, type, 'A'}}]}]}, #{}, #{})),
     ?_errorMatch({unrecognized_dict_import, {blup}},
                  import:import({import, #{}, [{symbol, #{}, variable, blap},
                                        {dict, #{}, [{blup}]}]}, #{}, #{})),
     ?_errorMatch({unrecognized_import, [{blip}]},
                  import:import({import, #{}, [{blip}]}, #{}, #{})),
     ?_errorMatch({nonexistent_module, blap},
                  test_import([blap, blip], #{})),
     ?_errorMatch({nonexistent_import, beam, random, blip},
                  test_import([random, blip], #{})),
     ?_errorMatch({nonexistent_import, source, blap, blip},
                  test_import([blap, blip], SourceMap))].
