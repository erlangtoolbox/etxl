-module(xl_vmfile_tests).

-include_lib("eunit/include/eunit.hrl").

pread_test() ->
    {ok, _} = xl_auto:using(xl_vmfile, [xl_eunit:resource(?MODULE, "vmfile.txt"), [{segment, 32}]], fun(File) ->
        ?assertEqual({ok, <<"1234567890">>}, file:pread(File, 0, 10)),
        ?assertEqual({ok, <<"6789012345">>}, file:pread(File, 5, 10)),
        ?assertEqual({ok, <<"6781\n22345">>}, file:pread(File, 45, 10)),
        ?assertEqual({ok, <<"67860">>}, file:pread(File, 295, 10)),
        ?assertEqual({ok, <<>>}, file:pread(File, 295, 0)),
        ?assertEqual(eof, file:pread(File, 395, 10)),
        ?assertEqual(eof, file:pread(File, 395, 0)),
        ?assertEqual(eof, file:pread(File, 300, 0)),
        ?assertEqual(eof, file:pread(File, 300, 1)),
        ?assertEqual({ok, <<"0">>}, file:pread(File, 299, 1)),
        ?assertEqual({ok, <<>>}, file:pread(File, 299, 0))
    end).

lines_test() ->
    F = xl_eunit:resource(?MODULE, "vmfile.txt"),
    Io = xl_file:using(F, [read], fun(File) -> xl_stream:to_list(xl_io:parse_lines(File)) end),
    Vm = xl_auto:using(xl_vmfile, [F, [{segment, 50}]], fun(File) -> xl_stream:to_list(xl_vmfile:parse_lines(File)) end),
    ?assertEqual(Io, Vm).


