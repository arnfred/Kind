-module(intersection).
-export([intersection/2]).

intersection(D, D) -> D;

intersection({recur, S}, {recur, T}) -> {recur, fun() -> intersection(S(), T()) end};
intersection({recur, S}, {sum, _} = D) -> {recur, fun() -> intersection(S(), D) end};
intersection({recur, S}, {product, _} = D) -> {recur, fun() -> intersection(S(), D) end};
intersection({recur, S}, {tagged, _, _} = D) -> {recur, fun() -> intersection(S(), D) end};
intersection({recur, _}, _) -> none;
intersection(D, {recur, S}) -> intersection({recur, S}, D);

intersection(D1, D2) when is_map(D1), is_map(D2) ->
    % When intersecting two maps we include all domains of the two maps.  This
    % is because a key is assumed to have domain `any` when it is not present
    % in a map and any narrower definition would need to be captured in the
    % intersection
    F = fun(K, _) -> case {maps:is_key(K, D1), maps:is_key(K, D2)} of
                         {true, true} -> intersection(maps:get(K, D1), maps:get(K, D2));
                         {false, true} -> maps:get(K, D2);
                         {true, false} -> maps:get(K, D1)
                     end
        end,
    maps:map(F, maps:merge(D1, D2));

intersection({error, E1}, {error, E2}) -> {error, E1 ++ E2};
intersection({error, _} = E, _) -> E;
intersection(_, {error, _} = E) -> E;

intersection(any, D) -> D;
intersection(D, any) -> D;
intersection(none, _) -> none;
intersection(_, none) -> none;

intersection({f, Name1, F1}, {f, Name2, F2}) -> 
    Name = list_to_atom(lists:flatten([atom_to_list(Name1), "_", atom_to_list(Name2)])), 
    case {domain_util:get_arity(F1), domain_util:get_arity(F2)} of
        {N, N} -> {f, Name, domain_util:mapfun(fun(Res1, Res2) -> intersection(Res1, Res2) end, F1, F2)};
        _ -> none
    end;

intersection({sum, D1}, {sum, D2}) -> 
    {sum, maps:from_list([{intersection(Dj, Di), true} || Di <- maps:keys(D1), Dj <- maps:keys(D2)])}; 
intersection({sum, D1}, D) -> 
    {sum, maps:from_list([{intersection(D, Di), true} || Di <- maps:keys(D1)])};
intersection(D, {sum, D1}) -> intersection({sum, D1}, D);

intersection({tagged, Tag, D1}, {tagged, Tag, D2}) -> 
    propagate_none({tagged, Tag, intersection(D1, D2)});
intersection({product, D1}, {product, D2}) -> propagate_none({product, intersection(D1, D2)});

intersection(_, _) -> none.

propagate_none({product, Map}) -> 
    case lists:member(none, maps:values(Map)) of
        true -> none;
        false -> {product, Map}
    end;
propagate_none({tagged, T, {product, Map}}) -> 
    case lists:member(none, maps:values(Map)) of
        true -> none;
        false -> {tagged, T, {product, Map}}
    end;
propagate_none(D) -> D.
