-module(xl_zip).

-export([unzip/2]).

-spec unzip/2 :: (file:name(), [term()]) -> error_m:monad(file:name()).
unzip(Name, Options) ->
    case zip:unzip(Name, Options) of
        Ok = {ok, _} -> Ok;
        E = {error, {_, _}} -> E;
        E -> xl_io:posix_error(E, {Name, Options})
    end.