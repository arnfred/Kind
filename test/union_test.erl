-module(union_test).

-include_lib("eunit/include/eunit.hrl").

union_array_test_() ->
    D = blip,
    Expected = blip,
    Actual = domain:union([D]),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_product_one_key_test_() ->
    D1 = {product, #{blip => true}},
    D2 = {product, #{blip => false}},
    Expected = {product, #{blip => {sum, ordsets:from_list([true, false])}}},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_product_two_keys_mergeable_test_() ->
    D1 = {product, #{blap => a, blip => true}},
    D2 = {product, #{blap => a, blip => false}},
    Expected = {product, #{blap => a, blip => {sum, ordsets:from_list([true, false])}}},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_product_two_keys_non_mergeable_test_() ->
    D1 = {product, #{blap => a, blip => true}},
    D2 = {product, #{blap => b, blip => false}},
    Expected = {sum, ordsets:from_list([{product, #{blap => a, blip => true}},
                                     {product, #{blap => b, blip => false}}])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_product_uneven_keys_mergeable_test_() ->
    D1 = {product, #{blap => a, blip => true}},
    D2 = {product, #{blip => true}},
    Expected = {product, #{blap => any, blip => true}},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_product_many_keys_test_() ->
    D1 = {product, #{blip => true, blap => false, blup => extra_old}},
    D2 = {product, #{blip => true, blap => true, blep => extra_new}},
    Expected = {sum, ordsets:from_list([{product, #{blip => true, blap => false, blup => extra_old}},
                                     {product, #{blip => true, blap => true, blep => extra_new}}])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_product_same_keys_test_() ->
    D1 = {product, #{blip => true, blap => false}},
    D2 = {product, #{blip => true, blap => true}},
    Expected = {product, #{blip => true, blap => {sum, ordsets:from_list([false, true])}}},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_test_() ->
    D1 = {sum, ordsets:from_list([a,b,c])},
    D2 = {sum, ordsets:from_list([b,c,d])},
    Expected = {sum, ordsets:from_list([a,b,c,d])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_none_test_() ->
    D1 = {sum, ordsets:from_list([none])},
    D2 = {sum, ordsets:from_list([a,b])},
    Expected = {sum, ordsets:from_list([a,b])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_tagged_same_test_() ->
    D1 = {tagged, kukkeluk, {product, #{blip => true}}},
    D2 = {tagged, kukkeluk, {product, #{blip => false}}},
    Expected = {tagged, kukkeluk, {product, #{blip => {sum, ordsets:from_list([true, false])}}}},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_tagged_diff_test_() ->
    D1 = {tagged, kukkeluk, {product, #{blip => true, blap => false, blup => extra_old}}},
    D2 = {tagged, kakkelak, {product, #{blip => true, blap => true, blep => extra_new}}},
    Expected = {sum, ordsets:from_list([{tagged, kukkeluk, {product, #{blip => true, blap => false, blup => extra_old}}},
                                     {tagged, kakkelak, {product, #{blip => true, blap => true, blep => extra_new}}}])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_of_products_test_() ->
    D1 = {sum, ordsets:from_list([{product, #{a => 1, b => 2}}])},
    D2 = {sum, ordsets:from_list([{product, #{a => 1, c => 3}}])},
    Expected = {sum, ordsets:from_list([{product, #{a => 1, b => 2}}, {product, #{a => 1, c => 3}}])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_of_many_products_test_() ->
    D1 = {sum, ordsets:from_list([{product, #{a => 1, b => 2, c => 1}},
                                  {product, #{a => 2, b => 2, c => 2}},
                                  {product, #{a => 1, b => 2, c => 3}},
                                  {product, #{a => 2, b => 2, c => 4}}])},
    D2 = {sum, ordsets:from_list([{product, #{a => 1}}])},
    Expected = {sum, ordsets:from_list([{product, #{a => 1, b => 2, c => {sum, ordsets:from_list([1, 3])}}}, 
                                        {product, #{a => 2, b => 2, c => {sum, ordsets:from_list([2, 4])}}},
                                        {product, #{a => 1}}])},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_with_none_test_() ->
    D1 = {sum, ordsets:from_list([{product, #{a => 1, b => 2, c => 1}}, none])},
    D2 = {sum, ordsets:from_list([none])},
    Expected = {product, #{a => 1, b => 2, c => 1}}, 
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_with_any_test_() ->
    D1 = {sum, ordsets:from_list([{product, #{a => 1, b => 2, c => 1}}, any])},
    D2 = {sum, ordsets:from_list([none])},
    Expected = any,
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_sum_of_products_with_same_keys_test_() ->
    D1 = {sum, ordsets:from_list([{product, #{a => 1, b => 2}}])},
    D2 = {sum, ordsets:from_list([{product, #{a => 1, b => 3}}])},
    Expected = {product, #{a => 1, b => {sum, ordsets:from_list([2,3])}}},
    Actual = domain:union(D1, D2),
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_recur_recur_sum_sum_test_() ->
    R = fun R() -> {sum, ordsets:from_list([a, b, {recur, R}])} end,
    S = fun S() -> {sum, ordsets:from_list([b, c, {recur, S}])} end,
    Actual = domain:union({recur, R}, {recur, S}),
    Expected = fun E() -> {sum, ordsets:from_list([a, b, c, {recur, E}])} end,
    [?_assertEqual(none, domain:diff(Expected(), Actual)),
     ?_assertMatch({sum, [a, b, c, {recur, _}]}, Actual)].

union_recur_constant_test_() ->
    R = fun R() -> {sum, ordsets:from_list([a, b, {recur, R}])} end,
    Actual = domain:union({recur, R}, blip),
    Expected = {sum, ordsets:from_list([blip, a, b, {recur, R}])},
    ?_assertEqual(none, domain:diff(Expected, Actual)).

union_recur_recur_sum_sum_sum_test_() ->
    R = fun R() -> {sum, ordsets:from_list([a, b, {recur, R}])} end,
    S = fun S() -> {sum, ordsets:from_list([b, c, {recur, S}])} end,
    Result = domain:union({recur, R}, {recur, S}),
    T = fun T() -> {sum, ordsets:from_list([c, d, {recur, T}])} end,
    Actual = domain:union(Result, T()),
    Expected = fun E() -> {sum, ordsets:from_list([a, b, c, d, {recur, E}])} end,
    [?_assertEqual(none, domain:diff(Expected(), Actual)),
     ?_assertMatch({sum, [a, b, c, d, {recur, _}]}, Actual)].

union_merge_recur_products_test() ->
    P1 = fun P1() -> {product, #{c => 2, b => {recur, P1}}} end,
    P2 = fun P2() -> {product, #{c => 2, b => {recur, P2}}} end,
    Actual = domain:union(P1(), P2()),
    io:format("Actual: ~p~n", domain:expand(10, [Actual])),
    Expected = {product, #{c => 2, b => {sum, ordsets:from_list([{recur, P1}, {recur, P2}])}}},
    ?assertEqual(none, domain:diff(Expected, Actual)).

union_merge_recur_products_with_single_key_test() ->
    P1 = fun P1() -> {product, #{r => {recur, P1}}} end,
    P2 = fun P2() -> {product, #{r => {recur, P2}}} end,
    Actual = domain:union(P1(), P2()),
    io:format("Actual: ~p~n", domain:expand(10, [Actual])),
    Expected = {product, #{r => {sum, ordsets:from_list([{recur, P1}, {recur, P2}])}}},
    ?assertEqual(none, domain:diff(Expected, Actual)).