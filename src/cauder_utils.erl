%%%-------------------------------------------------------------------
%%% @doc CauDEr utilities.
%%% @end
%%%-------------------------------------------------------------------

-module(cauder_utils).

-export([fundef_lookup/1]).
-export([find_spawn_action/2, find_spawn_parent/2, find_node_parent/2, find_msg_sender/2, find_msg_receiver/2]).
-export([
    find_process_with_future_reads/2,
    find_process_with_spawn/2,
    find_process_with_failed_spawn/2,
    find_process_with_start/2,
    find_process_on_node/2,
    find_process_with_failed_start/2,
    find_process_with_read/2,
    find_process_with_send/2,
    find_process_with_receive/2,
    find_process_with_variable/2,
    process_node/2
]).
-export([merge_bindings/2]).
-export([check_node_name/1]).
-export([string_to_expressions/1]).
-export([filter_options/2]).
-export([fresh_pid/0]).
-export([temp_variable/1, is_temp_variable_name/1]).
-export([gen_log_nodes/1, gen_log_send/2, gen_log_spawn/1, gen_log_start/1]).
-export([load_trace/1, trace_to_log/1]).
-export([is_dead/1]).
-export([is_conc_item/1]).
-export([race_sets/1, race_set/2]).
-export([queue_take/2]).

-elvis([{elvis_style, god_modules, disable}]).

% TODO Remove
-ignore_xref([race_sets/1, race_set/2]).

-include("cauder.hrl").

%%------------------------------------------------------------------------------
%% @doc Searches for the function definition that matches the given <i>MFA</i>.
%%
%% Returns a tuple is returned, where the first element is a boolean literal
%% that specifies whether the function is exported or not, and the second
%% element is the sequence of clauses of the matched function.
%% If a function is not loaded it tries to load it, if it fails the atom `error'
%% is returned.

-spec fundef_lookup(MFA) -> {Exported, Clauses} | error when
    MFA :: mfa(),
    Exported :: boolean(),
    Clauses :: cauder_types:af_clause_seq().

fundef_lookup({M, F, A}) ->
    case ets:match_object(?APP_DB, {{M, F, A, '_'}, '_'}) of
        [{{M, F, A, Exported}, Cs}] ->
            {Exported, Cs};
        [] ->
            Path = ets:lookup_element(?APP_DB, path, 2),
            File = filename:join(Path, atom_to_list(M) ++ ".erl"),
            case filelib:is_regular(File) of
                true ->
                    {ok, M} = cauder_load:file(File),
                    [{{M, F, A, Exported}, Cs}] = ets:match_object(?APP_DB, {{M, F, A, '_'}, '_'}),
                    {Exported, Cs};
                false ->
                    error
            end
    end.

%%------------------------------------------------------------------------------
%% @doc Searches for the given log entry in the given log map.
%% Returns `{value, Pid}' where `Pid' is the pid of the process whose log
%% contains the given entry, or `false' if the entry is not found.

-spec find_item(LMap, Entry) -> {value, Pid} | false when
    LMap :: cauder_types:log(),
    Entry :: cauder_types:log_action_search(),
    Pid :: cauder_types:proc_id().

find_item(LMap, Entry) ->
    Pair = lists:search(fun({_Pid, Log}) -> compare(Log, Entry) end, maps:to_list(LMap)),
    case Pair of
        {value, {Pid, _}} -> {value, Pid};
        false -> false
    end.

%%------------------------------------------------------------------------------
%% @doc Given two log items returns true if the second one matches the first.
%% The peculiarity of this function is that allows to search for log items
%% while not fully specifying their form, indeed the second item can be
%% called using the wildcard '_' when we are not interested in an element.

-spec compare(LogItem, Entry) -> true | false when
    LogItem :: [cauder_types:log_action()],
    Entry :: cauder_types:log_action_search().

compare([], _) -> false;
compare([H | _], H) -> true;
compare([{spawn, {_, Pid}, _} | _], {spawn, {_, Pid}, _}) -> true;
compare([{spawn, {Node, _}, failure} | _], {spawn, {Node, _}, failure}) -> true;
compare([_ | T], Entry) -> compare(T, Entry).

%%------------------------------------------------------------------------------
%% @doc Searches for a process whose log has an entry with the information to
%% spawn the process with the given pid.
%% Returns `{value, Pid}' where `Pid' is the pid of the process whose log
%% contains the aforementioned entry, or `false' if the entry is not found.

-spec find_spawn_parent(Log, Pid) -> {value, Parent} | false when
    Log :: cauder_types:log(),
    Pid :: cauder_types:proc_id(),
    Parent :: cauder_types:proc_id().

find_spawn_parent(Log, Pid) ->
    find_item(Log, {spawn, {'_', Pid}, '_'}).

%%---------------------------------------------------------------------------------
%% @doc Given a Pid and a Log, retrieves the action that will spawn the process
%% with the given Pid

-spec find_spawn_action(Log, Pid) -> Action when
    Log :: cauder_types:log(),
    Pid :: cauder_types:proc_id(),
    Action :: cauder_types:log_action_spawn().

find_spawn_action(Log, Pid) ->
    {value, Action} = lists:search(
        fun
            ({spawn, {_, SpawnPid}, _}) when Pid =:= SpawnPid -> true;
            (_) -> false
        end,
        lists:merge(maps:values(Log))
    ),
    Action.

%%------------------------------------------------------------------------------
%% @doc Searches for a process whose log has an entry with the information to
%% start the node with the given name.
%% Returns `{value, Pid}' where `Pid' is the pid of the process whose log
%% contains the aforementioned entry, or `false' if the entry is not found.

-spec find_node_parent(LMap, Node) -> {value, Parent} | false when
    LMap :: cauder_types:log(),
    Node :: node(),
    Parent :: cauder_types:proc_id().

find_node_parent(LMap, Node) ->
    find_item(LMap, {start, Node, success}).

%%------------------------------------------------------------------------------
%% @doc Searches for a process whose log has an entry with the information to
%% send the message with the given uid.
%% Returns `{value, Pid}' where `Pid' is the pid of the process whose log
%% contains the aforementioned entry, or `false' if the entry is not found.

-spec find_msg_sender(LMap, Uid) -> {value, Pid} | false when
    LMap :: cauder_types:log(),
    Uid :: cauder_mailbox:uid(),
    Pid :: cauder_types:proc_id().

find_msg_sender(LMap, Uid) ->
    find_item(LMap, {send, Uid}).

%%------------------------------------------------------------------------------
%% @doc Searches for a process whose log has an entry with the information to
%% receive the message with the given uid.
%% Returns `{value, Pid}' where `Pid' is the pid of the process whose log
%% contains the aforementioned entry, or `false' if the entry is not found.

-spec find_msg_receiver(LMap, Uid) -> {value, Pid} | false when
    LMap :: cauder_types:log(),
    Uid :: cauder_mailbox:uid(),
    Pid :: cauder_types:proc_id().

find_msg_receiver(LMap, Uid) ->
    find_item(LMap, {'receive', Uid}).

%%------------------------------------------------------------------------------
%% @doc Searches for the process that spawned the process with the given pid, by
%% looking at its history.

-spec find_process_with_spawn(ProcessMap, Pid) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Pid :: cauder_types:proc_id(),
    Process :: cauder_types:process().

find_process_with_spawn(PMap, Pid) ->
    lists:search(fun(#proc{hist = H}) -> has_spawn(H, Pid) end, maps:values(PMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for the process that started the node with the given name, by
%% looking at its history.

-spec find_process_with_start(ProcessMap, Node) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Node :: node(),
    Process :: cauder_types:process().

find_process_with_start(PMap, Node) ->
    lists:search(fun(#proc{hist = H}) -> has_start(H, Node) end, maps:values(PMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for the process(es) that tried to start `Node' and failed because
%% this was already part of the network, by looking at its history.

-spec find_process_with_failed_start(ProcessMap, Node) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Node :: node(),
    Process :: cauder_types:process().

find_process_with_failed_start(ProcessMap, Node) ->
    lists:search(fun(#proc{hist = H}) -> has_failed_start(H, Node) end, maps:values(ProcessMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for the process(es) that will fail to spawn `Node' and failed because
%% this was already part of the network, by looking at its log

-spec find_process_with_failed_spawn(LMap, Node) -> {value, Process} | false when
    LMap :: cauder_types:log(),
    Node :: node(),
    Process :: cauder_types:proc_id().

find_process_with_failed_spawn(LMap, Node) ->
    find_item(LMap, {spawn, {Node, '_'}, failure}).

%%------------------------------------------------------------------------------
%% @doc Searches for the process(es) that will do a read while `Node' was not part of the network

-spec find_process_with_future_reads(LMap, Node) -> {value, Process} | false when
    LMap :: cauder_types:log(),
    Node :: node(),
    Process :: cauder_types:proc_id().

find_process_with_future_reads(LMap, Node) ->
    lists:search(
        fun(Key) ->
            L = maps:get(Key, LMap),
            not will_always_read(L, Node) /= false
        end,
        maps:keys(LMap)
    ).

%%------------------------------------------------------------------------------
%% @doc Searches for process(es) running on `Node'

-spec find_process_on_node(ProcessMap, Node) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Node :: node(),
    Process :: cauder_types:process().

find_process_on_node(ProcessMap, Node) ->
    lists:search(fun(#proc{node = ProcNode}) -> ProcNode =:= Node end, maps:values(ProcessMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for process(es) that have performed a read of `Node' by means
%% of the function 'nodes()'

-spec find_process_with_read(ProcessMap, Node) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Node :: node(),
    Process :: cauder_types:process().

find_process_with_read(ProcessMap, Node) ->
    lists:search(fun(#proc{hist = H}) -> has_read(H, Node) end, maps:values(ProcessMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for the process that sent the message with the given uid, by
%% looking at its history.

-spec find_process_with_send(ProcessMap, Uid) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Uid :: cauder_mailbox:uid(),
    Process :: cauder_types:process().

find_process_with_send(PMap, Uid) ->
    lists:search(fun(#proc{hist = H}) -> has_send(H, Uid) end, maps:values(PMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for the process that received the message with the given uid,
%% by looking at its history.

-spec find_process_with_receive(ProcessMap, Uid) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Uid :: cauder_mailbox:uid(),
    Process :: cauder_types:process().

find_process_with_receive(PMap, Uid) ->
    lists:search(fun(#proc{hist = H}) -> has_rec(H, Uid) end, maps:values(PMap)).

%%------------------------------------------------------------------------------
%% @doc Searches for the process that defined the variable with the given name,
%% by looking at its history.

-spec find_process_with_variable(ProcessMap, Name) -> {value, Process} | false when
    ProcessMap :: cauder_types:process_map(),
    Name :: atom(),
    Process :: cauder_types:process().

find_process_with_variable(PMap, Name) ->
    lists:search(fun(#proc{env = Bs}) -> maps:is_key(Name, Bs) end, maps:values(PMap)).

%%------------------------------------------------------------------------------
%% @doc Merges the given collections of bindings into a new one.
%% If the same variable is defined in both collections but with different
%% values, then an exception is thrown.

-spec merge_bindings(Bindings1, Bindings2) -> Bindings3 when
    Bindings1 :: cauder_types:environment(),
    Bindings2 :: cauder_types:environment(),
    Bindings3 :: cauder_types:environment().

merge_bindings(Bs1, Bs2) ->
    maps:fold(
        fun
            (K, V, Bs) when not is_map_key(K, Bs) -> Bs#{K => V};
            (K, V, Bs) when map_get(K, Bs) =:= V -> Bs
        end,
        Bs1,
        Bs2
    ).

%%------------------------------------------------------------------------------
%% @doc Given an atom that represents a node checks that the format is correct.
%% Returns `error' if the format of the atom is not a valid Erlang node name.

-spec check_node_name(NodeName) -> ok | error | not_provided when
    NodeName :: string().

check_node_name([]) ->
    not_provided;
check_node_name(NodeName) ->
    case string:split(NodeName, "@") of
        [Name, Host] when length(Name) > 0, length(Host) > 0 ->
            ok;
        _ ->
            error
    end.

%%------------------------------------------------------------------------------
%% @doc Converts the given string into a list of abstract expressions.
%% Returns `error' if the string does not represent a valid Erlang expression.

-spec string_to_expressions(String) -> Expressions | error when
    String :: string(),
    Expressions :: [cauder_types:abstract_expr()].

string_to_expressions([]) ->
    [];
string_to_expressions(String) ->
    case erl_scan:string(String ++ ".") of
        {ok, Tokens, _} ->
            case erl_parse:parse_exprs(Tokens) of
                {ok, Value} -> cauder_syntax:expr_list(Value);
                _ -> error
            end;
        _ ->
            error
    end.

%%------------------------------------------------------------------------------
%% @doc Returns a new list containing only the options whose pid, matches the
%% given pid.

-spec filter_options(Options1, Pid) -> Options2 when
    Options1 :: [cauder_types:option()],
    Pid :: cauder_types:proc_id(),
    Options2 :: [cauder_types:option()].

filter_options(Options, Pid) ->
    lists:filter(fun(Opt) -> Opt#opt.pid =:= Pid end, Options).

%%------------------------------------------------------------------------------
%% @doc Checks whether the given history contains a `spawn' entry for the
%% process with the given pid or not.

-spec has_spawn(History, Pid) -> Result when
    History :: cauder_types:history(),
    Pid :: cauder_types:proc_id(),
    Result :: boolean().

has_spawn([], _) -> false;
has_spawn([{spawn, _Bs, _Es, _Stk, _Node, Pid} | _], Pid) -> true;
has_spawn([_ | RestHist], Pid) -> has_spawn(RestHist, Pid).

%%------------------------------------------------------------------------------
%% @doc Checks whether the given history contains a `start' entry for the
%% process with the given node or not.

-spec has_start(History, Node) -> Result when
    History :: cauder_types:history(),
    Node :: node(),
    Result :: boolean().

has_start([], _) -> false;
has_start([{start, success, _Bs, _Es, _Stk, Node} | _], Node) -> true;
has_start([_ | RestHist], Node) -> has_start(RestHist, Node).

%%------------------------------------------------------------------------------
%% @doc Checks whether the given history contains a failed `start' entry for
%% the given node or not.

-spec has_failed_start(History, Node) -> Result when
    History :: cauder_types:history(),
    Node :: node(),
    Result :: boolean().

has_failed_start([], _) -> false;
has_failed_start([{start, failure, _Bs, _Es, _Stk, Node} | _], Node) -> true;
has_failed_start([_ | RestHist], Node) -> has_failed_start(RestHist, Node).

%%------------------------------------------------------------------------------
%% @doc Checks whether the process will ever perform a read without `Node'

-spec will_always_read(Log, Node) -> Result when
    Log :: cauder_types:history(),
    Node :: node(),
    Result :: boolean().

will_always_read([], _) -> true;
will_always_read([{nodes, {Nodes}} | _], Node) -> lists:member(Node, Nodes);
will_always_read([_ | RestLog], Node) -> will_always_read(RestLog, Node).

%%------------------------------------------------------------------------------
%% @doc Checks whether the given history contains a read of `Node' by checking
%% the history item of the function 'nodes'

-spec has_read(History, Node) -> Result when
    History :: cauder_types:history(),
    Node :: node(),
    Result :: boolean().

has_read([], _) ->
    false;
has_read([{nodes, _Bs, _Es, _Stk, Nodes} | RestHist], Node) ->
    case lists:member(Node, Nodes) of
        true -> true;
        false -> has_read(RestHist, Node)
    end;
has_read([_ | RestHist], Node) ->
    has_read(RestHist, Node).

%%------------------------------------------------------------------------------
%% @doc Checks whether the given history contains a `send' entry for the message
%% with the given uid or not.

-spec has_send(History, Uid) -> Result when
    History :: cauder_types:history(),
    Uid :: cauder_mailbox:uid(),
    Result :: boolean().

has_send([], _) -> false;
has_send([{send, _Bs, _Es, _Stk, #message{uid = Uid}} | _], Uid) -> true;
has_send([_ | RestHist], Uid) -> has_send(RestHist, Uid).

%%------------------------------------------------------------------------------
%% @doc Checks whether the given history contains a `rec' entry for the message
%% with the given uid or not.

-spec has_rec(History, Uid) -> Result when
    History :: cauder_types:history(),
    Uid :: cauder_mailbox:uid(),
    Result :: boolean().

has_rec([], _) -> false;
has_rec([{rec, _Bs, _Es, _Stk, #message{uid = Uid}, _QPos} | _], Uid) -> true;
has_rec([_ | RestHist], Uid) -> has_rec(RestHist, Uid).

%%------------------------------------------------------------------------------
%% @doc Returns a new and unique process identifier.

-spec fresh_pid() -> Pid when
    Pid :: cauder_types:proc_id().

fresh_pid() -> ets:update_counter(?APP_DB, last_pid, 1, {last_pid, -1}).

%%------------------------------------------------------------------------------
%% @doc Returns a new and unique number to use as a variable suffix.
%%
%% @see temp_variable/1
%% @todo Merge with temp_variable/1?

-spec fresh_variable_number() -> Number when
    Number :: non_neg_integer().

fresh_variable_number() -> ets:update_counter(?APP_DB, last_var, 1, {last_var, -1}).

%%------------------------------------------------------------------------------
%% @doc Creates a variable with the name `k_<num>' being `<num>' a unique non
%% negative number.
%%
%% This variable is intended to be used as a temporal variable in calls where a
%% resulting value is not known immediately, so when the value is calculated it
%% can replace this variable.
%%
%% @see replace_variable/3

-spec temp_variable(Line) -> Variable when
    Line :: cauder_types:line(),
    Variable :: cauder_types:af_variable().

temp_variable(Line) ->
    Number = fresh_variable_number(),
    Name = "k_" ++ integer_to_list(Number),
    {var, Line, list_to_atom(Name)}.

%%------------------------------------------------------------------------------
%% @doc Checks if a variable is a temporary variable created by CauDEr.
%%
%% @see temp_variable/1

-spec is_temp_variable_name(Name) -> IsTemporary when
    Name :: atom(),
    IsTemporary :: boolean().

is_temp_variable_name(Name) ->
    case atom_to_list(Name) of
        "k_" ++ _ -> true;
        _ -> false
    end.

%%------------------------------------------------------------------------------
%% @doc Returns a roll log message about rolling the 'nodes()' of the process
%% with the given pid

-spec gen_log_nodes(Pid) -> [Log] when
    Pid :: cauder_types:proc_id(),
    Log :: [string()].

gen_log_nodes(Pid) ->
    [["Roll nodes of", cauder_pp:pid(Pid)]].

%%------------------------------------------------------------------------------
%% @doc Returns a roll log message about spawning a process with the given pid.

-spec gen_log_spawn(Pid) -> [Log] when
    Pid :: cauder_types:proc_id(),
    Log :: [string()].

gen_log_spawn(OtherPid) ->
    [["Roll spawn of ", cauder_pp:pid(OtherPid)]].

%%------------------------------------------------------------------------------
%% @doc Returns a roll log message about starting a node with the given name.

-spec gen_log_start(Node) -> [Log] when
    Node :: node(),
    Log :: [string()].

gen_log_start(Node) ->
    [["Roll start of ", cauder_pp:pp_node(Node)]].

%%------------------------------------------------------------------------------
%% @doc Returns a roll log message about sending a message with the given
%% information.

-spec gen_log_send(Pid, Message) -> [Log] when
    Pid :: cauder_types:proc_id(),
    Message :: cauder_mailbox:message(),
    Log :: [string()].

gen_log_send(Pid, #message{uid = Uid, value = Value, dest = Dest}) ->
    [
        [
            "Roll send from ",
            cauder_pp:pid(Pid),
            " of ",
            cauder_pp:to_string(Value),
            " to ",
            cauder_pp:pid(Dest),
            " (",
            cauder_pp:to_string(Uid),
            ")"
        ]
    ].

%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Load the trace result from the given directory adn returns it.

-spec load_trace(TraceDir) -> TraceInfo when
    TraceDir :: file:filename(),
    TraceInfo :: cauder_types:trace_info().

load_trace(Dir) ->
    ResultFile = filename:join(Dir, "trace_result.log"),
    {ok, ResultTerms} = file:consult(ResultFile),
    #{
        node := InitialNode,
        pid := InitialPid,
        call := {Mod, Fun, Args},
        tracing := Tracing,
        return := ReturnValue,
        comp := CompTime,
        exec := ExecTime
    } = maps:from_list(ResultTerms),

    Trace =
        filelib:fold_files(
            Dir,
            "trace_\\d+\\.log",
            false,
            fun(File, Acc) ->
                "trace_" ++ StringPid = filename:basename(File, ".log"),
                Pid = list_to_integer(StringPid),
                {ok, Terms0} = file:consult(File),
                find_last_message_uid(Terms0),
                Acc#{Pid => Terms0}
            end,
            maps:new()
        ),

    #trace_info{
        node = InitialNode,
        pid = InitialPid,
        call = {Mod, Fun, Args},
        tracing = Tracing,
        return = ReturnValue,
        comp = CompTime,
        exec = ExecTime,
        trace = Trace
    }.

-spec trace_to_log(Trace) -> Log when
    Trace :: cauder_types:trace(),
    Log :: cauder_types:log().

trace_to_log(Trace) ->
    maps:map(
        fun(_, Actions) ->
            lists:filtermap(
                fun
                    ({spawn, {Node, Pid}, Result}) -> {true, {spawn, {Node, Pid}, Result}};
                    ({send, Uid, _Pid, _Msg}) -> {true, {send, Uid}};
                    ({deliver, _Uid}) -> false;
                    ({'receive', Uid, _Constraints}) -> {true, {'receive', Uid}};
                    ({exit}) -> false;
                    ({nodes, Nodes}) -> {true, {nodes, Nodes}};
                    ({start, Node, Result}) -> {true, {start, Node, Result}}
                end,
                Actions
            )
        end,
        Trace
    ).

-spec find_last_message_uid(Terms) -> ok when
    Terms :: [cauder_types:log_action()].

find_last_message_uid(Terms) ->
    AllUids = lists:filtermap(
        fun
            ({send, Uid}) -> {true, Uid};
            (_) -> false
        end,
        Terms
    ),
    case AllUids of
        [] ->
            ok;
        _ ->
            true = ets:insert(?APP_DB, {last_uid, lists:max(AllUids)}),
            ok
    end.

%%------------------------------------------------------------------------------
%% @doc Checks whether a process has finished execution or not.

-spec is_dead(Process) -> IsDead when
    Process :: cauder_types:process(),
    IsDead :: boolean().

is_dead(#proc{exprs = [{value, _, _}], stack = []}) -> true;
is_dead(#proc{}) -> false.

%%------------------------------------------------------------------------------
%% @doc Returns the process node

-spec process_node(PMap, Pid) -> Result when
    PMap :: cauder_types:process_map(),
    Pid :: cauder_types:proc_id(),
    Result :: node() | false.

process_node(PMap, Pid) ->
    case maps:get(Pid, PMap, false) of
        false ->
            false;
        Proc ->
            #proc{node = Node} = Proc,
            Node
    end.

-spec is_conc_item(HistoryEntry) -> IsConcurrent when
    HistoryEntry :: cauder_types:history_entry(),
    IsConcurrent :: boolean().

is_conc_item({tau, _Bs, _Es, _Stk}) -> false;
is_conc_item({self, _Bs, _Es, _Stk}) -> false;
is_conc_item({node, _Bs, _Es, _Stk}) -> false;
is_conc_item({nodes, _Bs, _Es, _Stk, _Nodes}) -> true;
is_conc_item({start, success, _BS, _Es, _Stk, _Node}) -> true;
is_conc_item({start, failure, _BS, _Es, _Stk, _Node}) -> true;
is_conc_item({spawn, _Bs, _Es, _Stk, _Node, _Pid}) -> true;
is_conc_item({send, _Bs, _Es, _Stk, _Msg}) -> true;
is_conc_item({rec, _Bs, _Es, _Stk, _Msg, _QPos}) -> true.

%%%=============================================================================

-spec race_sets(Trace) -> RaceSets when
    Trace :: cauder_types:trace(),
    RaceSets :: cauder_types:race_sets().

race_sets(Trace) ->
    % TODO: OTP 24 - maps:filtermap/2
    RaceSets = maps:map(
        fun(Pid, Actions) ->
            lists:foldl(
                fun(Action, Acc) ->
                    case Action of
                        {'receive', Uid, _} ->
                            case race_set({Pid, Action}, Trace) of
                                [] ->
                                    Acc;
                                RaceSet ->
                                    Acc#{Uid => RaceSet}
                            end;
                        _ ->
                            Acc
                    end
                end,
                maps:new(),
                Actions
            )
        end,
        Trace
    ),
    maps:filter(fun(_, Map) -> maps:size(Map) =/= 0 end, RaceSets).

%%------------------------------------------------------------------------------
%% @doc Checks whether the condition `Event ∈ Trace' holds or not.

-spec event_belongs_to(Event, Trace) -> boolean() when
    Event :: {cauder_types:proc_id(), cauder_types:trace_action()},
    Trace :: cauder_types:trace().

event_belongs_to({P, Action}, Trace) -> lists:member(Action, maps:get(P, Trace)).

-spec race_set({Pid, ReceiveEvent}, Trace) -> RaceSet when
    Pid :: cauder_types:proc_id(),
    ReceiveEvent :: cauder_types:trace_action_receive(),
    Trace :: cauder_types:trace(),
    RaceSet :: cauder_types:race_set().

race_set({P, {'receive', L, Cs}} = Er, Trace) ->
    Ed = {P, {deliver, L}},

    true = event_belongs_to(Ed, Trace),
    true = event_belongs_to(Er, Trace),

    CaseClauses = lists:append(
        lists:map(fun({Pat, Guard}) -> erl_syntax:clause(Pat, Guard, [erl_syntax:atom('true')]) end, Cs),
        [erl_syntax:clause([erl_syntax:underscore()], none, [erl_syntax:atom('false')])]
    ),
    FunExpr = erl_syntax:revert(erl_syntax:fun_expr(CaseClauses)),
    {value, CheckFun, _Bs} = erl_eval:expr(FunExpr, erl_eval:new_bindings()),

    % Type: [{Pid, {send, Uid, Pid, Msg}}, ...]
    SendEvents = maps:fold(
        fun(P1, Actions, Acc) ->
            lists:foldl(
                fun
                    ({send, L1, Pid, V1} = Es, List) when P1 =/= Pid, L1 =/= L ->
                        case CheckFun(V1) of
                            true -> [{P1, Es} | List];
                            false -> List
                        end;
                    (_, List) ->
                        List
                end,
                Acc,
                Actions
            )
        end,
        [],
        Trace
    ),

    Graph = trace_graph(Trace),

    RaceSet =
        lists:foldl(
            fun({_P1, {send, L1, _, _}} = Es, Set) ->
                case
                    race_set_cond1(Ed, Es, Graph) andalso
                        race_set_cond2(Ed, L1, Trace, Graph) andalso
                        race_set_cond3(Ed, Es, SendEvents, CheckFun, Trace, Graph)
                of
                    true -> ordsets:add_element(L1, Set);
                    false -> Set
                end
            end,
            ordsets:new(),
            SendEvents
        ),
    digraph:delete(Graph),
    RaceSet.

-spec race_set_cond1(DeliverEvent, SendEvent, Graph) -> boolean() when
    DeliverEvent :: {cauder_types:proc_id(), cauder_types:trace_action_deliver()},
    SendEvent :: {cauder_types:proc_id(), cauder_types:trace_action_send()},
    Graph :: digraph:graph().

race_set_cond1(Ed, Es, G) ->
    not happened_before(Ed, Es, G).

-spec race_set_cond2(DeliverEvent, Uid, Trace, Graph) -> boolean() when
    DeliverEvent :: {cauder_types:proc_id(), cauder_types:trace_action_deliver()},
    Uid :: cauder_mailbox:uid(),
    Trace :: cauder_types:trace(),
    Graph :: digraph:graph().

race_set_cond2({P, {deliver, _L}} = Ed, L1, Trace, G) ->
    Ed1 = {P, {deliver, L1}},
    event_belongs_to(Ed1, Trace) andalso happened_before(Ed, Ed1, G).

-spec race_set_cond3(DeliverEvent, SendEvent, SendPairs, Constraints, Trace, Graph) -> boolean() when
    DeliverEvent :: {cauder_types:proc_id(), cauder_types:trace_action_deliver()},
    SendEvent :: {cauder_types:proc_id(), cauder_types:trace_action_send()},
    SendPairs :: [{cauder_types:proc_id(), cauder_types:trace_action_send()}],
    Constraints :: fun((term()) -> boolean()),
    Trace :: cauder_types:trace(),
    Graph :: digraph:graph().

race_set_cond3({P, {deliver, _L}} = Ed, {P1, {send, L1, P, _V1}} = Es1, SendEvents, Check, Trace, G) ->
    SendEvents1 = lists:filter(
        fun
            ({Pid, {send, L2, _, _}} = Es2) when Pid =:= P1, L2 =/= L1 ->
                happened_before(Es2, Es1, G);
            (_) ->
                false
        end,
        SendEvents
    ),

    lists:all(
        fun({_, {send, L2, _, V2}} = _SendEvent1) ->
            Ed2 = {P, {deliver, L2}},
            (not Check(V2)) orelse (event_belongs_to(Ed2, Trace) andalso happened_before(Ed2, Ed, G))
        end,
        SendEvents1
    ).

-spec happened_before(Event1, Event2, Graph) -> boolean() when
    Event1 :: {cauder_types:proc_id(), cauder_types:trace_action()},
    Event2 :: {cauder_types:proc_id(), cauder_types:trace_action()},
    Graph :: digraph:graph().

happened_before({_P1, A1}, {_P2, A2}, G) ->
    case digraph:get_path(G, A1, A2) of
        false -> false;
        _Path -> true
    end.

-spec trace_graph(Trace) -> Graph when
    Trace :: cauder_types:trace(),
    Graph :: digraph:graph().

trace_graph(Trace) ->
    G = digraph:new([acyclic]),

    AuxFun =
        fun(A, Map) ->
            digraph:add_vertex(G, A),
            case A of
                {spawn, _, success} ->
                    maps:update_with(spawn, fun(List) -> [A | List] end, [A], Map);
                {send, Uid, _, _} ->
                    maps:update_with(send, fun(Set) -> sets:add_element(Uid, Set) end, sets:from_list([Uid]), Map);
                {deliver, Uid} ->
                    maps:update_with(deliver, fun(Set) -> sets:add_element(Uid, Set) end, sets:from_list([Uid]), Map);
                {'receive', Uid, _} ->
                    maps:update_with('receive', fun(Set) -> sets:add_element(Uid, Set) end, sets:from_list([Uid]), Map);
                _ ->
                    Map
            end
        end,

    ActionTypes = lists:foldl(fun(As, Map) -> lists:foldl(AuxFun, Map, As) end, #{}, maps:values(Trace)),

    % Condition 1: p1 = p2, a1 != deliver(_), a2 != deliver(_), and a1 comes before a2 in the sequence T(p1)
    % Condition 2: p1 = p2, a1 = deliver(l), a2 != deliver(l'), l != l', and a1 comes before a2 in the sequence T(p1)
    lists:foreach(
        fun(Actions) ->
            [
                case {A1, A2} of
                    {{deliver, L1}, {deliver, L2}} when L1 =/= L2 -> digraph:add_edge(G, A1, A2);
                    {{deliver, _}, _} -> skip;
                    {_, {deliver, _}} -> skip;
                    {_, _} -> digraph:add_edge(G, A1, A2)
                end
             || A1 <- Actions, A2 <- tl(lists:dropwhile(fun(A) -> A =/= A1 end, Actions))
            ]
        end,
        maps:values(Trace)
    ),

    % Condition 3: a1 = spawn(p2), and p1 != p2
    lists:foreach(
        fun({spawn, {_, Pid}, success} = A1) ->
            lists:foreach(fun(A2) -> digraph:add_edge(G, A1, A2) end, maps:get(Pid, Trace))
        end,
        maps:get(spawn, ActionTypes, [])
    ),

    SendUids = maps:get(send, ActionTypes, sets:new()),
    DeliverUids = maps:get(deliver, ActionTypes, sets:new()),
    ReceiveUids = maps:get('receive', ActionTypes, sets:new()),

    % Condition 4: a1 = send(l), and a2 = deliver(l)
    true = sets:is_subset(DeliverUids, SendUids),
    lists:foreach(fun(Uid) -> digraph:add_edge(G, {send, Uid}, {deliver, Uid}) end, sets:to_list(DeliverUids)),

    % Condition 5: a1 = deliver(l), and a2 = receive(l)
    true = sets:is_subset(ReceiveUids, DeliverUids),
    lists:foreach(fun(Uid) -> digraph:add_edge(G, {deliver, Uid}, {'receive', Uid}) end, sets:to_list(ReceiveUids)),

    G.

-spec queue_take(Uid, Queue) -> {{Message, QPos}, NewQueue} | error when
    Uid :: cauder_mailbox:uid(),
    Queue :: queue:queue(cauder_mailbox:message()),
    Message :: cauder_mailbox:message(),
    QPos :: pos_integer(),
    NewQueue :: queue:queue(cauder_mailbox:message()).

queue_take(Uid, Queue) ->
    List0 = queue:to_list(Queue),
    case list_take(Uid, List0, [], 1) of
        {{Msg, QPos}, List1} -> {{Msg, QPos}, queue:from_list(List1)};
        error -> error
    end.

-spec list_take(Uid, List, Rest, Index) -> {{Message, MessageIndex}, NewList} | error when
    Uid :: cauder_mailbox:uid(),
    List :: [cauder_mailbox:message()],
    Rest :: [cauder_mailbox:message()],
    Index :: pos_integer(),
    Message :: cauder_mailbox:message(),
    MessageIndex :: pos_integer(),
    NewList :: [cauder_mailbox:message()].

list_take(Uid, [#message{uid = Uid} = Msg | List], Rest, Index) ->
    {{Msg, Index}, lists:reverse(Rest, List)};
list_take(Uid, [Msg | List], Rest, Index) ->
    list_take(Uid, List, [Msg | Rest], Index + 1);
list_take(_, [], _, _) ->
    error.
