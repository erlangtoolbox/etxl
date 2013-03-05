-module(xl_stream).

-export([stream/2, map/2, foreach/2, seq/2, foldl/3, filter/2, to_list/1,
    to_stream/1, to_pair/1, mapfind/2, empty/0, to_random_stream/1, keyfilter/3, eforeach/2, to_rpc_stream/1]).
-export([ifoldl/3]).

-opaque(stream(A) :: fun(() -> [A | stream(A)])).
-export_type([stream/1]).

stream(Context, Next) ->
    fun() ->
        case Next(Context) of
            empty -> [];
            {R, C} -> [R | stream(C, Next)]
        end
    end.

map(F, S) ->
    fun() ->
        case S() of
            [] -> [];
            [H | T] -> [F(H) | map(F, T)]
        end
    end.

foreach(F, S) ->
    case S() of
        [] -> ok;
        [H | T] -> F(H), foreach(F, T)
    end.

eforeach(F, S) ->
    case S() of
        [] -> ok;
        [H | T] ->
            case F(H) of
                ok -> eforeach(F, T);
                {ok, _} -> eforeach(F, T);
                E -> E
            end
    end.

seq(From, To) ->
    stream(From, fun(X) ->
        if
            X =< To -> {X, X + 1};
            true -> empty
        end
    end).

foldl(F, Acc0, S) ->
    case S() of
        [] -> Acc0;
        [H | T] -> foldl(F, F(H, Acc0), T)
    end.


ifoldl(F, Acc0, S) -> ifoldl(F, Acc0, 1, S).

ifoldl(F, Acc0, Index, S) ->
    case S() of
        [] -> Acc0;
        [H | T] -> ifoldl(F, F(H, Acc0, Index), Index + 1, T)
    end.


filter(P, S) ->
    fun() -> filter_next(P, S) end.

filter_next(P, S) ->
    case S() of
        [] -> [];
        [H | T] ->
            case P(H) of
                true -> [H | filter(P, T)];
                _ -> filter_next(P, T)
            end
    end.

to_list(S) -> lists:reverse(foldl(fun(V, L) -> [V | L] end, [], S)).

to_pair(S) -> S().

to_stream(L) when is_list(L) ->
    stream(L, fun
        ([]) -> empty;
        ([H | T]) -> {H, T}
    end).

-spec mapfind/2 :: (fun((any()) -> option_m:monad(any())), stream(any())) -> option_m:monad(any()).
mapfind(F, S) ->
    case S() of
        [] -> undefined;
        [H | T] ->
            case F(H) of
                undefined -> mapfind(F, T);
                R -> R
            end
    end.

empty() -> fun() -> [] end.

to_random_stream([]) -> empty();
to_random_stream(L) when is_list(L) ->
    Split = lists:split(xl_random:uniform(length(L)), L),
    stream(Split, fun
        ({[], []}) -> empty;
        ({[H | T], []}) -> {H, {T, []}};
        ({HL, [H | T]}) -> {H, {HL, T}}
    end).

keyfilter(Keys, KeyPos, S) -> fun() -> keyfilter_next(Keys, KeyPos, S) end.

keyfilter_next([], _KeyPos, _S) -> [];
keyfilter_next(Keys = [K | KT], KeyPos, S) ->
    case S() of
        [] -> [];
        [H | T] when K == element(KeyPos, H) -> [H | keyfilter(KT, KeyPos, T)];
        [H | T] when K > element(KeyPos, H) -> keyfilter_next(Keys, KeyPos, T);
        _ -> keyfilter_next(KT, KeyPos, S)
    end.

to_rpc_stream(S) ->
    stream({node(), S}, fun({Node, Stream}) ->
        case xl_rpc:call(Node, xl_stream, to_pair, [Stream]) of
            {ok, []} -> empty;
            {ok, [H | T]} -> {{ok, H}, {Node, T}};
            E -> {E, {Node, []}}
        end
    end).