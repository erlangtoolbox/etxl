-module(strikead_json_binder).

-export([compile/1, compile/2]).

-compile({parse_transform, do}).

compile([Path, Dest]) -> compile(Path, Dest).
compile(Path, Dest) ->
    Module = filename:basename(Path, filename:extension(Path)),
	HrlPath = filename:join([Dest, "include", Module ++ ".hrl"]),
	ModulePath = filename:join([Dest, "src", Module ++ ".erl"]),
	erlang:display("compile " ++ Path ++ " to " ++ Dest),
	ok = do([error_m ||
		Records <- file:consult(Path),
        generate_file(HrlPath, fun(F) -> generate_records(Records, F) end),
        generate_file(ModulePath, fun(F) -> generate_module(Records, Module, F) end)
	]).


generate_records([], _Out) -> ok;
generate_records([{Name, Fields} | T], Out) ->
	do([error_m||
		file:write(Out, "\n-record(" ++ atom_to_list(Name) ++ ", {\n\t" ++
            string:join([ generate_field(Field) || Field <- Fields], ",\n\t") ++
		"\n})."),
		generate_records(T, Out)
	]).

generate_field({Name, _Type, required}) -> atom_to_list(Name);
%string, integer, boolean, float, record
generate_field({Name, _T, optional}) -> atom_to_list(Name);
generate_field({Name, _T, {optional, Default}}) -> lists:flatten(io_lib:format("~p=~p", [Name, Default]));
generate_field(D) -> {error, {dont_understand, D}}.

generate_file(Path, Generate) ->
    erlang:display("...generating " ++ Path),
    do([error_m ||
        filelib:ensure_dir(Path),
        Out <- file:open(Path, [write]),
        Res <- return(
            do([error_m ||
                file:write(Out, "%% Generated by " ++ atom_to_list(?MODULE) ++ "\n"),
                Generate(Out)
            ])),
        file:close(Out),
        Res
    ]).

generate_module(Records, Name, Out) ->
    do([error_m ||
        file:write(Out, "-module(" ++ Name ++").\n\n"),
        file:write(Out, "-include(\"" ++ Name ++".hrl\").\n\n"),
        file:write(Out, "-export([to_json/1, from_json/2]).\n\n"),
        file:write(Out, "to_json(undefined) -> \"null\";\n\n"),
        generate_to_json(Records, Out),
        file:write(Out, "from_json(Json, Record) when is_list(Json); is_binary(Json) -> {J, _, _} = ktuo_json:decode(Json), from_json_(J, Record).\n\n"),
        file:write(Out, "from_json_(undefined, _Record)  -> undefined;\n\n"),
        generate_from_json(Records, Out)
    ]).

generate_to_json([], Out) -> file:write(Out, "to_json(X) -> {badarg, X}.\n\n");
generate_to_json([{Name, Fields} | T], Out) ->
    do([error_m ||
        io:format(Out, "to_json(R=#~p{}) -> \n", [Name]),
        file:write(Out, "\"{\"++"),
        generate_to_json_fields(Name, Fields, Out),
        file:write(Out, "++\"}\";\n\n"),
%        file:write(Out, sep(T, ";\n\n", ".\n\n")),
        generate_to_json(T, Out)
    ]).


generate_to_json_fields(_RecordName, [], _Out) -> ok;
generate_to_json_fields(RecordName, [Field | Fields], Out) ->
    do([error_m ||
        generate_to_json_field(RecordName, Field, Out),
        file:write(Out, sep(Fields, "++ \",\" ++\n", "\n")),
        generate_to_json_fields(RecordName, Fields, Out)
    ]).

generate_to_json_field(RecordName, {Name, string, _ }, Out) ->          io:format(Out, "case R#~p.~p of [] -> \"\\\"~p\\\": \\\"\\\"\"; X -> lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(X, undefined, null)])) end", [RecordName, Name, Name, Name]);
generate_to_json_field(RecordName, {Name, integer, _ }, Out) ->         io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, float, _ }, Out) ->           io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, boolean, _ }, Out) ->         io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, tuple, _ }, Out) ->           io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~s\", [strikead_json_rt:tuple2json(R#~p.~p)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, {list, string}, _ }, Out) ->  io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, {list, integer}, _ }, Out) -> io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, {list, float}, _ }, Out) ->   io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, {list, boolean}, _ }, Out) -> io:format(Out, "lists:flatten(io_lib:format(\"\\\"~p\\\": ~~p\", [strikead_json_rt:subst(R#~p.~p, undefined, null)]))", [Name, RecordName, Name]);
generate_to_json_field(RecordName, {Name, {list, _Rec}, _ }, Out) ->
    do([error_m ||
        io:format(Out, "\"\\\"~p\\\": [\" ++ ", [Name]),
        io:format(Out, "string:join([to_json(X)||X <- R#~p.~p], \",\") ++ ", [RecordName, Name]),
        file:write(Out, "\"]\"")
    ]);
generate_to_json_field(RecordName, {Name, _Rec, _ }, Out) -> io:format(Out, "\"\\\"~p\\\": \" ++ to_json(R#~p.~p)", [Name, RecordName, Name]);
generate_to_json_field(RecordName, Field, _Out) -> {error, {dont_understand, {RecordName, Field}}}.

sep([], _, S) -> S;
sep(_, S, _) -> S.

generate_from_json([], _Out) -> ok;
generate_from_json([{Name, Fields} | T], Out) ->
    do([error_m ||
        io:format(Out,"from_json_(J, ~p) -> \n", [Name]),
        io:format(Out, "#~p{", [Name]),
        generate_from_json_fields(Fields, Out),
        file:write(Out, sep(T, "};\n\n", "}.\n\n")),
        generate_from_json(T, Out)
    ]).

generate_from_json_fields([], _Out) -> ok;
generate_from_json_fields([Field | Fields], Out) ->
    do([error_m ||
        generate_from_json_field(Field, Out),
        file:write(Out, sep(Fields, ",\n", "\n")),
        generate_from_json_fields(Fields, Out)
    ]).


generate_from_json_field({Name, string, _ }, Out) ->          io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, integer, _ }, Out) ->         io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, float, _ }, Out) ->           io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, boolean, _ }, Out) ->         io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, {list, string}, _ }, Out) ->  io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, {list, integer}, _ }, Out) -> io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, {list, float}, _ }, Out) ->   io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, {list, boolean}, _ }, Out) -> io:format(Out, "~p = strikead_json_rt:from_dict(~p, J)",[Name, Name]);
generate_from_json_field({Name, {list, Rec}, _ }, Out) -> io:format(Out, "~p = [from_json_(O, ~p) || O <- strikead_json_rt:from_dict(~p, J)]",[Name, Rec, Name]);
generate_from_json_field({Name, Rec, _ }, Out) -> io:format(Out, "~p = from_json_(strikead_json_rt:from_dict(~p, J), ~p)",[Name, Name, Rec]);
generate_from_json_field(Field, _Out) -> {error, {dont_understand, Field}}.